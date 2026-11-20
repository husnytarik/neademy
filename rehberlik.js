import { db } from './db.js';
import { sifrele, coz } from './gizli.js';
import {
  tamSayi, kisa, uzun, bugun, tarihGecerli, saatGecerli, Hata, hataYanit, islem,
  okullarim, okulSec, ogrenciAl, ogrenciSatiri, benimOgrencilerim, kapsamOgrencileri, yonetimYetkisi,
} from './okul-ortak.js';
import { okulKapsami, kapsamdaMi } from './kapsam.js';

// Rehberlik: görüşme kayıtları, testler ve anketler.
//  - Görüşme notları şifreli durur; "gizli" işaretli kayıtların içeriğini yalnızca yazan görür.
//  - Test ve anket aynı motoru kullanır: sorular, hedef (öğrenci ya da veli), sınıf süzgeci. Testte seçenekler puanlıdır ve puana göre yorum çıkar.
//  - Anonim ankette cevap sahibi sonuçlarda hiçbir yerde gösterilmez.
db.exec(`
CREATE TABLE IF NOT EXISTS rehber_gorusmeleri (
  id                    INTEGER PRIMARY KEY,
  student_membership_id INTEGER NOT NULL REFERENCES memberships(id),
  branch_id             INTEGER NOT NULL REFERENCES branches(id),
  tarih                 TEXT NOT NULL,
  saat                  TEXT NOT NULL DEFAULT '',
  tur                   TEXT NOT NULL DEFAULT 'ogrenci',
  konu                  TEXT NOT NULL,
  ozet                  TEXT NOT NULL DEFAULT '',
  yapilan               TEXT NOT NULL DEFAULT '',
  takip_tarihi          TEXT NOT NULL DEFAULT '',
  takip_tamam           INTEGER NOT NULL DEFAULT 0,
  gizli                 INTEGER NOT NULL DEFAULT 0,
  yazan_user_id         INTEGER NOT NULL REFERENCES users(id),
  created_at            INTEGER NOT NULL,
  updated_at            INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS rehber_gorusme_ogrenci ON rehber_gorusmeleri (student_membership_id, tarih);
CREATE TABLE IF NOT EXISTS rehber_formlar (
  id             INTEGER PRIMARY KEY,
  branch_id      INTEGER NOT NULL REFERENCES branches(id),
  tur            TEXT NOT NULL,
  ad             TEXT NOT NULL,
  aciklama       TEXT NOT NULL DEFAULT '',
  hedef          TEXT NOT NULL DEFAULT 'ogrenci',
  sinif_ids      TEXT NOT NULL DEFAULT '[]',
  sorular        TEXT NOT NULL DEFAULT '[]',
  yorumlar       TEXT NOT NULL DEFAULT '[]',
  anonim         INTEGER NOT NULL DEFAULT 0,
  sonuc_goster   INTEGER NOT NULL DEFAULT 0,
  durum          TEXT NOT NULL DEFAULT 'taslak',
  son_tarih      TEXT NOT NULL DEFAULT '',
  olusturan_user_id INTEGER NOT NULL REFERENCES users(id),
  created_at     INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS rehber_cevaplar (
  id                      INTEGER PRIMARY KEY,
  form_id                 INTEGER NOT NULL REFERENCES rehber_formlar(id) ON DELETE CASCADE,
  student_membership_id   INTEGER NOT NULL REFERENCES memberships(id),
  cevaplayan_membership_id INTEGER NOT NULL REFERENCES memberships(id),
  cevaplar                TEXT NOT NULL,
  puan                    REAL,
  giren_user_id           INTEGER REFERENCES users(id),
  created_at              INTEGER NOT NULL,
  UNIQUE (form_id, student_membership_id, cevaplayan_membership_id)
);
`);

const TURLER = { ogrenci: 'Öğrenciyle', veli: 'Veliyle', ogretmen: 'Öğretmenle', diger: 'Diğer' };
const LIKERT = ['Hiç katılmıyorum', 'Katılmıyorum', 'Kararsızım', 'Katılıyorum', 'Tamamen katılıyorum'];
const SORU_TIPLERI = ['likert', 'secenek', 'evet-hayir', 'metin'];
const EVET_HAYIR = ['Evet', 'Hayır'];
const SINIRLAR = { soru: 60, secenek: 10, yorum: 10 };

const gizliCoz = r => ({ konu: coz(r.konu), ozet: coz(r.ozet), yapilan: coz(r.yapilan) });

function gorusmeSatiri(r, o) {
  const acik = !r.gizli || r.yazan_user_id === o.user_id;
  return {
    id: r.id, ogrenciId: r.student_membership_id, ogrenci: r.ogrenci, sinif: r.sinif || '', okul: r.okul || '',
    tarih: r.tarih, saat: r.saat, tur: r.tur, turAd: TURLER[r.tur] || '', gizli: !!r.gizli, yazan: r.yazan, benim: r.yazan_user_id === o.user_id,
    takipTarihi: r.takip_tarihi, takipTamam: !!r.takip_tamam, icerikAcik: acik,
    ...(acik ? gizliCoz(r) : { konu: 'Gizli görüşme', ozet: '', yapilan: '' }),
  };
}
const GORUSME_SQL = `SELECT g.*, u.full_name AS ogrenci, c.name AS sinif, b.name AS okul, y.full_name AS yazan
  FROM rehber_gorusmeleri g JOIN memberships m ON m.id = g.student_membership_id JOIN users u ON u.id = m.user_id
  JOIN users y ON y.id = g.yazan_user_id JOIN branches b ON b.id = g.branch_id
  LEFT JOIN class_students cs ON cs.student_membership_id = m.id LEFT JOIN classes c ON c.id = cs.class_id`;

// ---- Form (test / anket) yardımcıları ----

// İstemciden gelen soru listesini doğrular ve temizler
function sorulariTemizle(ham, tur) {
  if (!Array.isArray(ham)) throw new Hata(400, 'Sorular geçersiz');
  if (ham.length > SINIRLAR.soru) throw new Hata(400, `En çok ${SINIRLAR.soru} soru eklenebilir`);
  return ham.map((s, i) => {
    const metin = kisa(s?.metin, 300);
    const tip = SORU_TIPLERI.includes(s?.tip) ? s.tip : null;
    if (metin.length < 2) throw new Hata(400, `${i + 1}. sorunun metnini yazın`);
    if (!tip) throw new Hata(400, `${i + 1}. sorunun türü geçersiz`);
    if (tur === 'test' && tip === 'metin') throw new Hata(400, 'Testte serbest yazı sorusu olamaz');
    const soru = { metin, tip };
    if (tip === 'secenek') {
      const sec = (Array.isArray(s.secenekler) ? s.secenekler : []).map(x => ({ metin: kisa(x?.metin, 120), puan: Number.isFinite(Number(x?.puan)) ? Math.max(-100, Math.min(100, Number(x.puan))) : 0 })).filter(x => x.metin);
      if (sec.length < 2 || sec.length > SINIRLAR.secenek) throw new Hata(400, `${i + 1}. soru için 2-${SINIRLAR.secenek} seçenek yazın`);
      soru.secenekler = sec;
    }
    if (tur === 'test' && (tip === 'likert' || tip === 'evet-hayir')) soru.ters = !!s.ters;
    return soru;
  });
}
function yorumlariTemizle(ham) {
  if (!Array.isArray(ham)) return [];
  return ham.slice(0, SINIRLAR.yorum).map(y => ({ min: Number(y?.min), max: Number(y?.max), baslik: kisa(y?.baslik, 80), aciklama: uzun(y?.aciklama, 400) }))
    .filter(y => Number.isFinite(y.min) && Number.isFinite(y.max) && y.baslik && y.min <= y.max);
}

// Bir cevap dizisinin puanı (yalnızca test)
function puanla(sorular, cevaplar) {
  let toplam = 0;
  sorular.forEach((s, i) => {
    const c = cevaplar[i];
    if (s.tip === 'likert') toplam += s.ters ? 6 - c : c;
    else if (s.tip === 'evet-hayir') toplam += s.ters ? (c === 1 ? 1 : 0) : (c === 0 ? 1 : 0);
    else if (s.tip === 'secenek') toplam += s.secenekler[c].puan;
  });
  return toplam;
}
function enYuksekPuan(sorular) {
  return sorular.reduce((t, s) => t + (s.tip === 'likert' ? 5 : s.tip === 'evet-hayir' ? 1 : s.tip === 'secenek' ? Math.max(...s.secenekler.map(x => x.puan)) : 0), 0);
}
const yorumBul = (yorumlar, puan) => yorumlar.find(y => puan >= y.min && puan <= y.max) || null;

// Cevapları soru türüne göre doğrular; metin sorusu boş bırakılabilir (null)
function cevaplariDogrula(sorular, ham) {
  if (!Array.isArray(ham) || ham.length !== sorular.length) throw new Hata(400, 'Tüm soruları yanıtlayın');
  return sorular.map((s, i) => {
    const c = ham[i];
    if (s.tip === 'metin') return c === null || c === undefined || c === '' ? null : uzun(c, 500);
    if (c === null || c === undefined || c === '') throw new Hata(400, `${i + 1}. soruyu yanıtlayın`);
    const n = Number(c);
    const gecerli = s.tip === 'likert' ? Number.isInteger(n) && n >= 1 && n <= 5
      : s.tip === 'evet-hayir' ? n === 0 || n === 1
      : Number.isInteger(n) && n >= 0 && n < s.secenekler.length;
    if (!gecerli) throw new Hata(400, `${i + 1}. soru için seçim geçersiz`);
    return n;
  });
}

function formSatiri(f) {
  return {
    id: f.id, okulId: f.branch_id, tur: f.tur, ad: f.ad, aciklama: f.aciklama, hedef: f.hedef, sinifIds: JSON.parse(f.sinif_ids), sorular: JSON.parse(f.sorular),
    yorumlar: JSON.parse(f.yorumlar), anonim: !!f.anonim, sonucGoster: !!f.sonuc_goster, durum: f.durum, sonTarih: f.son_tarih, olusturma: f.created_at,
  };
}

// Formun hedef kitlesi: [{ ogrenciId, ad, sinif, cevaplayanlar:[membershipId] }] (veli ise öğrencinin velileri, öğrenci ise kendisi)
function hedefKitle(f) {
  const sinifIds = JSON.parse(f.sinif_ids);
  const ogrenciler = db.prepare(`SELECT m.id, u.full_name AS ad, cs.class_id AS sinifId, c.name AS sinif
    FROM memberships m JOIN users u ON u.id = m.user_id LEFT JOIN class_students cs ON cs.student_membership_id = m.id LEFT JOIN classes c ON c.id = cs.class_id
    WHERE m.role = 'ogrenci' AND m.status = 'aktif' AND m.branch_id = ? ORDER BY c.name, u.full_name`).all(f.branch_id)
    .filter(r => !sinifIds.length || sinifIds.includes(r.sinifId));
  if (f.hedef === 'ogrenci') return ogrenciler.map(r => ({ ogrenciId: r.id, ad: r.ad, sinif: r.sinif || '', cevaplayanlar: [r.id] }));
  const veliler = db.prepare(`SELECT g.student_membership_id AS ogr, g.parent_membership_id AS veli FROM guardians g
    JOIN memberships vm ON vm.id = g.parent_membership_id AND vm.status = 'aktif'`).all();
  const harita = new Map();
  for (const v of veliler) harita.set(v.ogr, [...(harita.get(v.ogr) || []), v.veli]);
  return ogrenciler.map(r => ({ ogrenciId: r.id, ad: r.ad, sinif: r.sinif || '', cevaplayanlar: harita.get(r.id) || [] }));
}

// Bu form bu öğrenci için (ve bu cevaplayana) şu an açık mı? Açıksa form satırını döner, değilse hata fırlatır
function formAcikMi(formId, ogrenciId, cevaplayanId, hedef) {
  const f = db.prepare('SELECT * FROM rehber_formlar WHERE id = ?').get(tamSayi(formId) || 0);
  const ogr = ogrenciSatiri(Number(ogrenciId));
  if (!f || !ogr || ogr.subeId !== f.branch_id || f.hedef !== hedef) throw new Hata(404, 'Form bulunamadı');
  const sinifIds = JSON.parse(f.sinif_ids);
  if (sinifIds.length && !sinifIds.includes(ogr.sinifId)) throw new Hata(404, 'Form bulunamadı');
  if (f.durum !== 'acik') throw new Hata(409, 'Bu form şu an cevaba açık değil');
  if (f.son_tarih && f.son_tarih < bugun()) throw new Hata(409, 'Bu formun süresi dolmuş');
  return { f, ogr };
}

function cevapKaydet(f, ogrenciId, cevaplayanId, cevaplar, girenUserId) {
  const sorular = JSON.parse(f.sorular);
  const temiz = cevaplariDogrula(sorular, cevaplar);
  const puan = f.tur === 'test' ? puanla(sorular, temiz) : null;
  try {
    db.prepare('INSERT INTO rehber_cevaplar (form_id, student_membership_id, cevaplayan_membership_id, cevaplar, puan, giren_user_id, created_at) VALUES (?,?,?,?,?,?,?)')
      .run(f.id, ogrenciId, cevaplayanId, JSON.stringify(temiz), puan, girenUserId, Date.now());
  } catch (e) {
    if (String(e.message).includes('UNIQUE')) throw new Hata(409, 'Bu form daha önce yanıtlanmış');
    throw e;
  }
  return { puan, enYuksek: f.tur === 'test' ? enYuksekPuan(sorular) : null, yorum: f.tur === 'test' ? yorumBul(JSON.parse(f.yorumlar), puan) : null };
}

function formYetkisi(o, id) {
  const f = db.prepare('SELECT * FROM rehber_formlar WHERE id = ?').get(tamSayi(id) || 0);
  if (!f || !kapsamdaMi(okulKapsami(o), f.branch_id)) throw new Hata(404, 'Form bulunamadı');
  return f;
}

// Form sonuçları: soru bazında dağılım + (anonim değilse) kişi bazında liste
function formSonuc(f) {
  const sorular = JSON.parse(f.sorular);
  const yorumlar = JSON.parse(f.yorumlar);
  const kitle = hedefKitle(f);
  const cevaplar = db.prepare('SELECT * FROM rehber_cevaplar WHERE form_id = ? ORDER BY created_at').all(f.id);
  const ogrenciAdi = new Map(kitle.map(k => [k.ogrenciId, k]));
  const parsed = cevaplar.map(c => ({ ...c, liste: JSON.parse(c.cevaplar) }));
  const sorularSonuc = sorular.map((s, i) => {
    const r = { metin: s.metin, tip: s.tip };
    if (s.tip === 'metin') { r.yanitlar = parsed.map(c => c.liste[i]).filter(Boolean); return r; }
    const etiketler = s.tip === 'likert' ? LIKERT : s.tip === 'evet-hayir' ? EVET_HAYIR : s.secenekler.map(x => x.metin);
    const sayilar = etiketler.map(() => 0);
    for (const c of parsed) sayilar[s.tip === 'likert' ? c.liste[i] - 1 : c.liste[i]]++;
    r.dagilim = etiketler.map((e, j) => ({ etiket: e, sayi: sayilar[j] }));
    if (s.tip === 'likert' && parsed.length) r.ortalama = Math.round(parsed.reduce((t, c) => t + c.liste[i], 0) / parsed.length * 100) / 100;
    return r;
  });
  const beklenen = f.hedef === 'ogrenci' ? kitle.length : kitle.filter(k => k.cevaplayanlar.length).length;
  const cevapOgrenciler = new Set(parsed.map(c => c.student_membership_id));
  const sonuc = {
    form: { ...formSatiri(f), sorular }, hedefSayisi: kitle.length, cevapSayisi: parsed.length,
    // Veli formunda bir öğrenci birden çok veli tarafından yanıtlanabilir: katılım öğrenci bazında sayılır
    katilanOgrenci: cevapOgrenciler.size, beklenen, sorularSonuc, enYuksek: f.tur === 'test' ? enYuksekPuan(sorular) : null,
  };
  if (f.tur === 'test') {
    const puanlar = parsed.map(c => c.puan);
    sonuc.ortalamaPuan = puanlar.length ? Math.round(puanlar.reduce((t, p) => t + p, 0) / puanlar.length * 10) / 10 : null;
    sonuc.yorumDagilimi = yorumlar.map(y => ({ baslik: y.baslik, sayi: puanlar.filter(p => p >= y.min && p <= y.max).length }));
  }
  if (!f.anonim) {
    sonuc.kisiler = parsed.map(c => {
      const k = ogrenciAdi.get(c.student_membership_id);
      return { cevapId: c.id, ogrenciId: c.student_membership_id, ad: k?.ad || '—', sinif: k?.sinif || '', puan: c.puan, yorum: f.tur === 'test' ? (yorumBul(yorumlar, c.puan)?.baslik || '') : '', tarih: new Date(c.created_at).toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' }) };
    });
    sonuc.cevaplamayanlar = kitle.filter(k => k.cevaplayanlar.length && !cevapOgrenciler.has(k.ogrenciId)).map(k => ({ ogrenciId: k.ogrenciId, ad: k.ad, sinif: k.sinif }));
  }
  return sonuc;
}

export async function rehberlikApi({ req, res, url, o, json, govde, denetle }) {
  const yol = url.pathname;
  if (!yol.startsWith('/api/rehberlik/')) return false;
  const yonetici = yonetimYetkisi(o, 'rehberlik');
  const cevaplayan = o.role === 'ogrenci' || o.role === 'veli';
  try {
    // =============== Öğrenci / veli: bekleyen ve çözülmüş formlar ===============
    if (req.method === 'GET' && yol === '/api/rehberlik/benim') {
      if (!cevaplayan) throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const hedef = o.role;
      const cocuklar = benimOgrencilerim(o).filter(c => c.durum === 'aktif');
      const liste = [];
      for (const c of cocuklar) {
        const formlar = db.prepare("SELECT * FROM rehber_formlar WHERE branch_id = ? AND hedef = ? AND durum != 'taslak' ORDER BY created_at DESC").all(c.subeId, hedef);
        for (const f of formlar) {
          const sinifIds = JSON.parse(f.sinif_ids);
          if (sinifIds.length && !sinifIds.includes(c.sinifId)) continue;
          const cevap = db.prepare('SELECT * FROM rehber_cevaplar WHERE form_id = ? AND student_membership_id = ? AND cevaplayan_membership_id = ?').get(f.id, c.id, o.membership_id);
          const sureDoldu = f.son_tarih && f.son_tarih < bugun();
          if (!cevap && (f.durum !== 'acik' || sureDoldu)) continue;
          const oge = { formId: f.id, ad: f.ad, tur: f.tur, aciklama: f.aciklama, sonTarih: f.son_tarih, ogrenciId: c.id, ogrenciAd: c.ad, cevaplandi: !!cevap, sonuc: null };
          if (cevap && f.tur === 'test' && f.sonuc_goster) {
            const sorular = JSON.parse(f.sorular);
            oge.sonuc = { puan: cevap.puan, enYuksek: enYuksekPuan(sorular), yorum: yorumBul(JSON.parse(f.yorumlar), cevap.puan) };
          }
          liste.push(oge);
        }
      }
      return json(res, 200, { formlar: liste, cocukSayisi: cocuklar.length }), true;
    }
    // Cevaplanacak formun soruları (puan ve yorum bilgisi gönderilmez)
    if (req.method === 'GET' && yol === '/api/rehberlik/form-cevap') {
      if (!cevaplayan) throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const ogr = ogrenciAl(o, url.searchParams.get('ogrenci'));
      const { f } = formAcikMi(url.searchParams.get('id'), ogr.id, o.membership_id, o.role);
      const cevap = db.prepare('SELECT 1 FROM rehber_cevaplar WHERE form_id = ? AND student_membership_id = ? AND cevaplayan_membership_id = ?').get(f.id, ogr.id, o.membership_id);
      if (cevap) throw new Hata(409, 'Bu form daha önce yanıtlanmış');
      const sorular = JSON.parse(f.sorular).map(s => ({ metin: s.metin, tip: s.tip, secenekler: s.tip === 'secenek' ? s.secenekler.map(x => x.metin) : s.tip === 'likert' ? LIKERT : s.tip === 'evet-hayir' ? EVET_HAYIR : undefined }));
      return json(res, 200, { form: { id: f.id, ad: f.ad, tur: f.tur, aciklama: f.aciklama, anonim: !!f.anonim }, ogrenci: { id: ogr.id, ad: ogr.ad }, sorular }), true;
    }
    if (req.method === 'POST' && yol === '/api/rehberlik/cevap') {
      if (!cevaplayan) throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const g = await govde(req);
      const ogr = ogrenciAl(o, g.ogrenciId);
      const { f } = formAcikMi(g.formId, ogr.id, o.membership_id, o.role);
      const s = cevapKaydet(f, ogr.id, o.membership_id, g.cevaplar, o.user_id);
      return json(res, 200, { tamam: true, sonuc: f.tur === 'test' && f.sonuc_goster ? s : null }), true;
    }

    // =============== Rehberlik yetkilisi ===============
    if (!yonetici) throw new Hata(403, 'Bu işlem için yetkiniz yok');

    if (req.method === 'GET' && yol === '/api/rehberlik/baglam') {
      const okullar = okullarim(o);
      const siniflar = db.prepare('SELECT id, name AS ad, branch_id AS okulId FROM classes ORDER BY name').all().filter(c => okullar.some(b => b.id === c.okulId));
      const kapsamIdleri = okullar.map(b => b.id);
      const yer = kapsamIdleri.map(() => '?').join(',') || 'NULL';
      const sonOtuz = new Date(Date.now() - 30 * 86400000).toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
      const gorusme30 = db.prepare(`SELECT COUNT(*) AS n FROM rehber_gorusmeleri WHERE branch_id IN (${yer}) AND tarih >= ?`).get(...kapsamIdleri, sonOtuz).n;
      const takipler = db.prepare(`${GORUSME_SQL} WHERE g.branch_id IN (${yer}) AND g.takip_tarihi != '' AND g.takip_tamam = 0 AND g.takip_tarihi <= ? ORDER BY g.takip_tarihi LIMIT 50`)
        .all(...kapsamIdleri, new Date(Date.now() + 7 * 86400000).toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' }))
        .map(r => gorusmeSatiri(r, o));
      const acikFormlar = db.prepare(`SELECT COUNT(*) AS n FROM rehber_formlar WHERE branch_id IN (${yer}) AND durum = 'acik'`).get(...kapsamIdleri).n;
      return json(res, 200, { okullar, siniflar, turler: TURLER, likert: LIKERT, ozet: { gorusme30, acikFormlar }, takipler }), true;
    }
    if (req.method === 'GET' && yol === '/api/rehberlik/ogrenciler') {
      const liste = kapsamOgrencileri(o, { okul: url.searchParams.get('okul'), sinif: url.searchParams.get('sinif'), ara: url.searchParams.get('ara') }).slice(0, 300);
      return json(res, 200, { ogrenciler: liste.map(r => ({ id: r.id, ad: r.ad, sinif: r.sinif || '', okul: r.okul || '' })) }), true;
    }

    // ---- Görüşmeler ----
    if (req.method === 'GET' && yol === '/api/rehberlik/gorusmeler') {
      const kapsamIdleri = okullarim(o).map(b => b.id);
      const yer = kapsamIdleri.map(() => '?').join(',') || 'NULL';
      const ogrenci = tamSayi(url.searchParams.get('ogrenci'));
      const okul = tamSayi(url.searchParams.get('okul'));
      let sql = `${GORUSME_SQL} WHERE g.branch_id IN (${yer})`;
      const p = [...kapsamIdleri];
      if (ogrenci) { sql += ' AND g.student_membership_id = ?'; p.push(ogrenci); }
      if (okul) { sql += ' AND g.branch_id = ?'; p.push(okul); }
      const ara = kisa(url.searchParams.get('ara'), 60).toLocaleLowerCase('tr');
      let satirlar = db.prepare(sql + ' ORDER BY g.tarih DESC, g.saat DESC, g.id DESC LIMIT 600').all(...p).map(r => gorusmeSatiri(r, o));
      if (ara) satirlar = satirlar.filter(r => [r.ogrenci, r.konu, r.sinif].some(x => x.toLocaleLowerCase('tr').includes(ara)));
      return json(res, 200, { gorusmeler: satirlar }), true;
    }
    if (req.method === 'POST' && yol === '/api/rehberlik/gorusme') {
      const g = await govde(req);
      const ogr = ogrenciAl(o, g.ogrenciId);
      if (ogr.iliski !== 'yonetim') throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const tarih = g.tarih || bugun();
      const saat = g.saat === undefined || g.saat === '' ? '' : g.saat;
      const konu = kisa(g.konu, 150);
      const takip = g.takipTarihi || '';
      if (!tarihGecerli(tarih) || tarih > bugun()) throw new Hata(400, 'Görüşme tarihi geçersiz');
      if (saat && !saatGecerli(saat)) throw new Hata(400, 'Saat geçersiz');
      if (konu.length < 2) throw new Hata(400, 'Konuyu yazın');
      if (takip && (!tarihGecerli(takip) || takip < tarih)) throw new Hata(400, 'Takip tarihi geçersiz');
      const tur = Object.hasOwn(TURLER, g.tur) ? g.tur : 'ogrenci';
      const deger = [sifrele(konu), sifrele(uzun(g.ozet, 4000)), sifrele(uzun(g.yapilan, 2000)), takip, g.gizli ? 1 : 0];
      if (g.id) {
        const e = db.prepare('SELECT * FROM rehber_gorusmeleri WHERE id = ?').get(tamSayi(g.id) || 0);
        if (!e || e.student_membership_id !== ogr.id) throw new Hata(404, 'Kayıt bulunamadı');
        if (e.yazan_user_id !== o.user_id) throw new Hata(403, 'Görüşmeyi yalnızca yazan değiştirebilir');
        db.prepare('UPDATE rehber_gorusmeleri SET tarih = ?, saat = ?, tur = ?, konu = ?, ozet = ?, yapilan = ?, takip_tarihi = ?, gizli = ?, takip_tamam = CASE WHEN takip_tarihi = ? THEN takip_tamam ELSE 0 END, updated_at = ? WHERE id = ?')
          .run(tarih, saat, tur, ...deger, takip, Date.now(), e.id);
        denetle(o.user_id, 'rehberlik.gorusme-guncelle', { ogrenciId: ogr.id, gorusmeId: e.id });
        return json(res, 200, { tamam: true, id: e.id }), true;
      }
      const r = db.prepare(`INSERT INTO rehber_gorusmeleri (student_membership_id, branch_id, tarih, saat, tur, konu, ozet, yapilan, takip_tarihi, gizli, yazan_user_id, created_at, updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(ogr.id, ogr.subeId, tarih, saat, tur, ...deger, o.user_id, Date.now(), Date.now());
      denetle(o.user_id, 'rehberlik.gorusme', { ogrenciId: ogr.id, gorusmeId: Number(r.lastInsertRowid) });
      return json(res, 200, { tamam: true, id: Number(r.lastInsertRowid) }), true;
    }
    if (req.method === 'POST' && yol === '/api/rehberlik/gorusme-sil') {
      const g = await govde(req);
      const e = db.prepare('SELECT * FROM rehber_gorusmeleri WHERE id = ?').get(tamSayi(g.id) || 0);
      if (!e || !kapsamdaMi(okulKapsami(o), e.branch_id)) throw new Hata(404, 'Kayıt bulunamadı');
      if (e.yazan_user_id !== o.user_id) throw new Hata(403, 'Görüşmeyi yalnızca yazan silebilir');
      db.prepare('DELETE FROM rehber_gorusmeleri WHERE id = ?').run(e.id);
      denetle(o.user_id, 'rehberlik.gorusme-sil', { ogrenciId: e.student_membership_id, gorusmeId: e.id });
      return json(res, 200, { tamam: true }), true;
    }
    if (req.method === 'POST' && yol === '/api/rehberlik/gorusme-takip') {
      const g = await govde(req);
      const e = db.prepare('SELECT * FROM rehber_gorusmeleri WHERE id = ?').get(tamSayi(g.id) || 0);
      if (!e || !kapsamdaMi(okulKapsami(o), e.branch_id)) throw new Hata(404, 'Kayıt bulunamadı');
      db.prepare('UPDATE rehber_gorusmeleri SET takip_tamam = ? WHERE id = ?').run(g.tamam ? 1 : 0, e.id);
      return json(res, 200, { tamam: true }), true;
    }
    // Öğrenci dosyası özeti: görüşmeler + test sonuçları
    if (req.method === 'GET' && yol === '/api/rehberlik/ogrenci') {
      const ogr = ogrenciAl(o, url.searchParams.get('id'));
      if (ogr.iliski !== 'yonetim') throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const gorusmeler = db.prepare(`${GORUSME_SQL} WHERE g.student_membership_id = ? ORDER BY g.tarih DESC, g.id DESC LIMIT 200`).all(ogr.id).map(r => gorusmeSatiri(r, o));
      const sonuclar = db.prepare(`SELECT c.*, f.ad, f.tur, f.yorumlar, f.sorular, f.hedef FROM rehber_cevaplar c JOIN rehber_formlar f ON f.id = c.form_id
        WHERE c.student_membership_id = ? AND f.anonim = 0 ORDER BY c.created_at DESC LIMIT 100`).all(ogr.id).map(c => ({
        ad: c.ad, tur: c.tur, hedef: c.hedef, puan: c.puan, enYuksek: c.tur === 'test' ? enYuksekPuan(JSON.parse(c.sorular)) : null,
        yorum: c.tur === 'test' ? (yorumBul(JSON.parse(c.yorumlar), c.puan)?.baslik || '') : '', tarih: new Date(c.created_at).toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' }),
      }));
      return json(res, 200, { ogrenci: { id: ogr.id, ad: ogr.ad, sinif: ogr.sinif || '', okul: ogr.okul || '' }, gorusmeler, sonuclar }), true;
    }

    // ---- Test ve anketler ----
    if (req.method === 'GET' && yol === '/api/rehberlik/formlar') {
      const kapsamIdleri = okullarim(o).map(b => b.id);
      const yer = kapsamIdleri.map(() => '?').join(',') || 'NULL';
      const formlar = db.prepare(`SELECT f.*, b.name AS okul, (SELECT COUNT(*) FROM rehber_cevaplar c WHERE c.form_id = f.id) AS cevap FROM rehber_formlar f JOIN branches b ON b.id = f.branch_id
        WHERE f.branch_id IN (${yer}) ORDER BY f.created_at DESC`).all(...kapsamIdleri);
      return json(res, 200, { formlar: formlar.map(f => ({ id: f.id, okul: f.okul, okulId: f.branch_id, tur: f.tur, ad: f.ad, hedef: f.hedef, durum: f.durum, sonTarih: f.son_tarih, anonim: !!f.anonim, soruSayisi: JSON.parse(f.sorular).length, cevapSayisi: f.cevap, sinifSayisi: JSON.parse(f.sinif_ids).length })) }), true;
    }
    if (req.method === 'GET' && yol === '/api/rehberlik/form') {
      return json(res, 200, { form: formSatiri(formYetkisi(o, url.searchParams.get('id'))) }), true;
    }
    if (req.method === 'POST' && yol === '/api/rehberlik/form-kaydet') {
      const g = await govde(req, 80_000);
      const tur = g.tur === 'test' ? 'test' : 'anket';
      const ad = kisa(g.ad, 120);
      if (ad.length < 3) throw new Hata(400, 'Başlık en az 3 karakter olmalı');
      const hedef = g.hedef === 'veli' ? 'veli' : 'ogrenci';
      const sonTarih = g.sonTarih || '';
      if (sonTarih && !tarihGecerli(sonTarih)) throw new Hata(400, 'Son tarih geçersiz');
      const sorular = sorulariTemizle(g.sorular ?? [], tur);
      const yorumlar = tur === 'test' ? yorumlariTemizle(g.yorumlar) : [];
      const okulId = g.id ? formYetkisi(o, g.id).branch_id : okulSec(o, g.okulId);
      const sinifIds = [...new Set((Array.isArray(g.sinifIds) ? g.sinifIds : []).map(Number))];
      for (const sid of sinifIds) {
        const c = db.prepare('SELECT branch_id FROM classes WHERE id = ?').get(sid);
        if (!c || c.branch_id !== okulId) throw new Hata(400, 'Sınıf bu okula ait değil');
      }
      const deger = [ad, uzun(g.aciklama, 800), hedef, JSON.stringify(sinifIds), JSON.stringify(sorular), JSON.stringify(yorumlar), tur === 'anket' && g.anonim ? 1 : 0, tur === 'test' && g.sonucGoster ? 1 : 0, sonTarih];
      if (g.id) {
        const f = formYetkisi(o, g.id);
        const cevapVar = db.prepare('SELECT 1 FROM rehber_cevaplar WHERE form_id = ?').get(f.id);
        if (cevapVar && (JSON.stringify(sorular) !== f.sorular || tur !== f.tur || hedef !== f.hedef || (tur === 'anket' && !!g.anonim !== !!f.anonim))) {
          throw new Hata(409, 'Cevap gelmiş bir formun soruları, türü, hedefi ve gizlilik ayarı değiştirilemez');
        }
        db.prepare('UPDATE rehber_formlar SET tur = ?, ad = ?, aciklama = ?, hedef = ?, sinif_ids = ?, sorular = ?, yorumlar = ?, anonim = ?, sonuc_goster = ?, son_tarih = ? WHERE id = ?')
          .run(tur, ...deger, f.id);
        denetle(o.user_id, 'rehberlik.form-guncelle', { formId: f.id });
        return json(res, 200, { tamam: true, id: f.id }), true;
      }
      const r = db.prepare(`INSERT INTO rehber_formlar (branch_id, tur, ad, aciklama, hedef, sinif_ids, sorular, yorumlar, anonim, sonuc_goster, son_tarih, olusturan_user_id, created_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(okulId, tur, ...deger, o.user_id, Date.now());
      denetle(o.user_id, 'rehberlik.form', { formId: Number(r.lastInsertRowid), tur });
      return json(res, 200, { tamam: true, id: Number(r.lastInsertRowid) }), true;
    }
    if (req.method === 'POST' && yol === '/api/rehberlik/form-durum') {
      const g = await govde(req);
      const f = formYetkisi(o, g.id);
      const durum = ['taslak', 'acik', 'kapali'].includes(g.durum) ? g.durum : null;
      if (!durum) throw new Hata(400, 'Durum geçersiz');
      if (durum === 'acik' && !JSON.parse(f.sorular).length) throw new Hata(400, 'Yayınlamadan önce soru ekleyin');
      if (durum === 'acik' && f.tur === 'test' && !JSON.parse(f.yorumlar).length && f.sonuc_goster) throw new Hata(400, 'Sonucu göstermek için puan aralıklarına yorum ekleyin');
      if (durum === 'taslak' && db.prepare('SELECT 1 FROM rehber_cevaplar WHERE form_id = ?').get(f.id)) throw new Hata(409, 'Cevap gelmiş form taslağa alınamaz; kapatabilirsiniz');
      db.prepare('UPDATE rehber_formlar SET durum = ? WHERE id = ?').run(durum, f.id);
      denetle(o.user_id, 'rehberlik.form-durum', { formId: f.id, durum });
      return json(res, 200, { tamam: true }), true;
    }
    if (req.method === 'POST' && yol === '/api/rehberlik/form-sil') {
      const g = await govde(req);
      const f = formYetkisi(o, g.id);
      islem(() => { db.prepare('DELETE FROM rehber_cevaplar WHERE form_id = ?').run(f.id); db.prepare('DELETE FROM rehber_formlar WHERE id = ?').run(f.id); });
      denetle(o.user_id, 'rehberlik.form-sil', { formId: f.id, ad: f.ad });
      return json(res, 200, { tamam: true }), true;
    }
    if (req.method === 'GET' && yol === '/api/rehberlik/form-sonuc') {
      return json(res, 200, formSonuc(formYetkisi(o, url.searchParams.get('id')))), true;
    }
    // Öğrenci/veli adına cevap girişi (kâğıt uygulanan test ya da anketler için)
    if (req.method === 'POST' && yol === '/api/rehberlik/cevap-gir') {
      const g = await govde(req);
      const f = formYetkisi(o, g.formId);
      const ogr = ogrenciAl(o, g.ogrenciId);
      if (ogr.iliski !== 'yonetim' || ogr.subeId !== f.branch_id) throw new Hata(404, 'Öğrenci bulunamadı');
      if (f.anonim) throw new Hata(400, 'Anonim ankete adına cevap girilemez');
      const sinifIds = JSON.parse(f.sinif_ids);
      if (sinifIds.length && !sinifIds.includes(ogr.sinifId)) throw new Hata(400, 'Öğrenci formun hedef sınıflarında değil');
      let cevaplayanId = ogr.id;
      if (f.hedef === 'veli') {
        cevaplayanId = tamSayi(g.veliId) || db.prepare('SELECT parent_membership_id AS id FROM guardians WHERE student_membership_id = ? ORDER BY parent_membership_id LIMIT 1').get(ogr.id)?.id;
        if (!cevaplayanId || !db.prepare('SELECT 1 FROM guardians WHERE student_membership_id = ? AND parent_membership_id = ?').get(ogr.id, cevaplayanId)) throw new Hata(400, 'Öğrencinin velisi bulunamadı');
      }
      const s = cevapKaydet(f, ogr.id, cevaplayanId, g.cevaplar, o.user_id);
      denetle(o.user_id, 'rehberlik.cevap-gir', { formId: f.id, ogrenciId: ogr.id });
      return json(res, 200, { tamam: true, sonuc: s }), true;
    }
    if (req.method === 'POST' && yol === '/api/rehberlik/cevap-sil') {
      const g = await govde(req);
      const c = db.prepare('SELECT * FROM rehber_cevaplar WHERE id = ?').get(tamSayi(g.id) || 0);
      const f = c && db.prepare('SELECT * FROM rehber_formlar WHERE id = ?').get(c.form_id);
      if (!f || !kapsamdaMi(okulKapsami(o), f.branch_id) || f.anonim) throw new Hata(404, 'Kayıt bulunamadı');
      db.prepare('DELETE FROM rehber_cevaplar WHERE id = ?').run(c.id);
      denetle(o.user_id, 'rehberlik.cevap-sil', { formId: f.id, ogrenciId: c.student_membership_id });
      return json(res, 200, { tamam: true }), true;
    }
  } catch (e) { return hataYanit(res, json, e); }
  return false;
}
