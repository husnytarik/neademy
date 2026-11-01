import { db } from './db.js';
import { DERS_ZAMANLARI } from './okul-ayar.js';
import { tarihAcik, tatilAdi } from './tatil.js';
import { dersStilleri, stilEkle } from './stil.js';
import { ogretmenKulupDersleri } from './kulup.js';
import { gorevAraligi } from './gorev.js';
import { ogretmenToplantilari } from './zumrem.js';

// Öğretmenin takvimi: ders, kulüp, etüt, nöbet, görevlendirme, toplantı, ödev, sınav, rapor, görüşme ve doğum günleri tek listede (ay ızgarası için tam haftalarla)
const bugun = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
const gunNo = t => new Date(t + 'T00:00:00Z').getUTCDay();
const kaydir = (t, n) => {
  const d = new Date(t + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};
const dakikaEkle = (saat, dk) => {
  const t = Number(saat.slice(0, 2)) * 60 + Number(saat.slice(3, 5)) + dk;
  return `${String(Math.floor(t / 60) % 24).padStart(2, '0')}:${String(t % 60).padStart(2, '0')}`;
};
const aralik = p => DERS_ZAMANLARI[p - 1] || ['', ''];

export async function takvimApi({ req, res, url, o, json }) {
  if (req.method !== 'GET' || url.pathname !== '/api/takvim') return false;
  if (o.role !== 'ogretmen') { json(res, 403, { hata: 'Bu işlem için yetkiniz yok' }); return true; }
  const ay = url.searchParams.get('ay') || bugun().slice(0, 7);
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(ay)) { json(res, 400, { hata: 'Ay geçersiz' }); return true; }

  const ilk = ay + '-01';
  const bas = kaydir(ilk, -((gunNo(ilk) + 6) % 7));
  const sonGun = new Date(Date.UTC(Number(ay.slice(0, 4)), Number(ay.slice(5)), 0)).toISOString().slice(0, 10);
  const bit = kaydir(sonGun, (7 - gunNo(sonGun)) % 7);
  const st = dersStilleri();

  const program = db.prepare(`SELECT s.day, s.period, a.class_id AS sinifId, c.name AS sinif, co.name AS ders
    FROM schedule s JOIN assignments a ON a.id = s.assignment_id JOIN classes c ON c.id = a.class_id JOIN courses co ON co.id = a.course_id
    WHERE a.teacher_membership_id = ? ORDER BY s.period`).all(o.membership_id);
  const yoklamalar = new Map(db.prepare('SELECT class_id, date, period, completed_at, cancelled FROM yoklama WHERE date BETWEEN ? AND ?')
    .all(bas, bit).map(y => [`${y.class_id}|${y.date}|${y.period}`, y]));
  const etutler = db.prepare(`SELECT e.topic AS konu, e.date, e.start_time AS saat, e.duration_min AS sure, e.place AS yer, co.name AS ders,
      (SELECT COUNT(*) FROM etut_katilimcilar k WHERE k.etut_id = e.id) AS kisi
    FROM etutler e LEFT JOIN courses co ON co.id = e.course_id
    WHERE e.date BETWEEN ? AND ? AND e.teacher_membership_id = ? AND e.status = 'planli'`).all(bas, bit, o.membership_id);
  const gorevler = db.prepare('SELECT * FROM gorevler WHERE user_id = ?').all(o.user_id);
  const toplantilar = ogretmenToplantilari(o.membership_id, bas, bit);
  const odevler = db.prepare(`SELECT od.title AS baslik, od.due_date AS tarih, co.name AS ders, c.name AS sinif
    FROM odevler od JOIN assignments a ON a.id = od.assignment_id JOIN classes c ON c.id = a.class_id JOIN courses co ON co.id = a.course_id
    WHERE a.teacher_membership_id = ? AND od.due_date BETWEEN ? AND ?`).all(o.membership_id, bas, bit);
  const sinavlar = db.prepare(`SELECT p.name AS baslik, p.date AS tarih,
      (SELECT GROUP_CONCAT(c.name, ', ') FROM sinav_siniflar ss JOIN classes c ON c.id = ss.class_id WHERE ss.sinav_id = p.id) AS siniflar
    FROM sinavlar p WHERE p.teacher_membership_id = ? AND p.date BETWEEN ? AND ?`).all(o.membership_id, bas, bit);
  const calismalar = db.prepare(`SELECT kc.tarih, kc.tur, kc.baslik, k.ad AS kulup FROM kulup_calismalar kc JOIN kulupler k ON k.id = kc.kulup_id
    WHERE kc.teacher_membership_id = ? AND kc.iptal = 0 AND kc.tarih BETWEEN ? AND ?`).all(o.membership_id, bas, bit);
  const subeId = db.prepare('SELECT branch_id FROM memberships WHERE id = ?').get(o.membership_id)?.branch_id;
  const donemler = db.prepare('SELECT * FROM gelisim_donemleri WHERE branch_id = ?').all(subeId);
  const gorusmeler = db.prepare(`SELECT g.tarih, g.tur, u.full_name AS ogrenci FROM gelisim_gorusmeleri g
    JOIN memberships m ON m.id = g.student_membership_id JOIN users u ON u.id = m.user_id
    WHERE g.yazan_membership_id = ? AND g.tarih BETWEEN ? AND ?`).all(o.membership_id, bas, bit);
  // Mentor (sınıf) öğretmeninin öğrencilerinin doğum günleri
  const dogumlar = db.prepare(`SELECT u.full_name AS ad, k.dogum_tarihi AS dogum, c.name AS sinif
    FROM classes c JOIN class_students cs ON cs.class_id = c.id JOIN memberships m ON m.id = cs.student_membership_id AND m.status = 'aktif'
    JOIN users u ON u.id = m.user_id JOIN ogrenci_kayit k ON k.student_membership_id = m.id
    WHERE c.homeroom_membership_id = ? AND k.dogum_tarihi <> ''`).all(o.membership_id);
  const GORUSME = { toplanti: 'Veli toplantısı', gorusme: 'Veli görüşmesi' };

  const gunler = [];
  for (let t = bas; t <= bit; t = kaydir(t, 1)) {
    const gun = gunNo(t), acik = tarihAcik(t), ogeler = [];
    if (acik) {
      for (const r of program.filter(x => x.day === gun)) {
        const y = yoklamalar.get(`${r.sinifId}|${t}|${r.period}`);
        const [b, s] = aralik(r.period);
        ogeler.push(stilEkle({
          tur: 'ders', bas: b, bit: s, baslik: r.ders, alt: `${r.period}. ders · ${r.sinif}`, ders: r.ders,
          durum: y?.cancelled ? 'iptal' : y?.completed_at ? 'tamam' : '',
          baglanti: `/derslerim?tarih=${t}&sinifId=${r.sinifId}&dersSaati=${r.period}`,
        }, st));
      }
      for (const d of ogretmenKulupDersleri(o.membership_id, t)) {
        const [b, s] = aralik(d.dersSaati);
        ogeler.push(stilEkle({
          tur: 'ders', bas: b, bit: s, baslik: 'Kulüp', alt: `${d.dersSaati}. ders · ${d.sinif}`, ders: d.ders,
          durum: d.alindi ? 'tamam' : '', baglanti: `/derslerim?tarih=${t}&kulupId=${d.kulupId}&dersSaati=${d.dersSaati}`,
        }, st));
      }
    }
    for (const e of etutler.filter(x => x.date === t)) {
      ogeler.push({
        tur: 'etut', bas: e.saat, bit: dakikaEkle(e.saat, e.sure || 0), baslik: `Etüt · ${e.ders || 'Genel'}`,
        alt: [e.konu, e.yer, e.kisi ? `${e.kisi} öğrenci` : ''].filter(Boolean).join(' · '), baglanti: '/etut',
      });
    }
    for (const g of gorevler) {
      if (g.tekrar === 'haftalik' ? !(acik && g.day === gun) : g.tarih !== t) continue;
      const ar = gorevAraligi(g);
      ogeler.push({ tur: g.tur, bas: ar?.[0] || '', bit: ar?.[1] || '', baslik: g.ad, alt: g.yer });
    }
    for (const m of toplantilar.filter(x => x.tarih === t)) {
      ogeler.push({ tur: 'toplanti', bas: m.saat, bit: '', baslik: m.baslik, alt: [m.zumre, m.yer].filter(Boolean).join(' · '), baglanti: m.baskanlar ? '/baskan-toplantilari' : '/zumrem' });
    }
    for (const od of odevler.filter(x => x.tarih === t)) {
      ogeler.push({ tur: 'odev', bas: '', bit: '', baslik: od.baslik, alt: `Son teslim · ${od.ders} · ${od.sinif}`, baglanti: '/odevler' });
    }
    for (const p of sinavlar.filter(x => x.tarih === t)) {
      ogeler.push({ tur: 'sinav', bas: '', bit: '', baslik: p.baslik, alt: p.siniflar || '', baglanti: '/sinav' });
    }
    for (const c of calismalar.filter(x => x.tarih === t)) {
      ogeler.push({ tur: 'kulup', bas: '', bit: '', baslik: c.baslik, alt: `${c.kulup} · ${c.tur}`, baglanti: '/kulupler' });
    }
    for (const d of donemler) {
      const alt = `${d.ad} dönemi`;
      if (d.baslangic === t) ogeler.push({ tur: 'rapor', bas: '', bit: '', baslik: 'Gelişim raporu girişi başlıyor', alt, baglanti: '/gelisim' });
      if (d.bitis === t) ogeler.push({ tur: 'rapor', bas: '', bit: '', baslik: 'Gelişim raporu girişi son gün', alt, baglanti: '/gelisim' });
      if (d.toplanti_tarihi === t) ogeler.push({ tur: 'veli', bas: '', bit: '', baslik: 'Veli toplantısı', alt, baglanti: '/gelisim' });
    }
    for (const g of gorusmeler.filter(x => x.tarih === t)) {
      ogeler.push({ tur: 'gorusme', bas: '', bit: '', baslik: g.ogrenci, alt: GORUSME[g.tur] || 'Veli görüşmesi', baglanti: '/gelisim' });
    }
    for (const d of dogumlar) {
      if (d.dogum.slice(5) !== t.slice(5)) continue;
      const yas = Number(t.slice(0, 4)) - Number(d.dogum.slice(0, 4));
      ogeler.push({ tur: 'dogum', bas: '', bit: '', baslik: d.ad, alt: `Doğum günü${yas > 0 && yas < 30 ? ` · ${yas}. yaş` : ''} · ${d.sinif}` });
    }
    ogeler.sort((x, y) => x.bas.localeCompare(y.bas) || x.bit.localeCompare(y.bit));
    gunler.push({ tarih: t, gun, acik, tatil: tatilAdi(t), ogeler });
  }
  json(res, 200, { ay, bugun: bugun(), bas, bit, gunler });
  return true;
}
