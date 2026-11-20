import { db } from './db.js';
import { sifrele, coz } from './gizli.js';
import {
  tamSayi, kisa, uzun, saatGecerli, Hata, hataYanit, islem,
  okullarim, okulSec, ogrenciAl, benimOgrencilerim, kapsamOgrencileri, yonetimYetkisi,
} from './okul-ortak.js';
import { okulKapsami, kapsamdaMi } from './kapsam.js';

// Öğrenci servisi: okul servis araçları, güzergâh durakları ve öğrencilerin servise bağlanması.
// Bir öğrenci en çok bir servise bağlıdır (durak ve yön: sabah / akşam / gidiş-dönüş). Şoför ve hostes telefonları şifreli durur.
// Veli ve öğrenci yalnızca kendi servis bilgisini (araç, şoför, durak, saat) görür.
db.exec(`
CREATE TABLE IF NOT EXISTS servisler (
  id         INTEGER PRIMARY KEY,
  branch_id  INTEGER NOT NULL REFERENCES branches(id),
  ad         TEXT NOT NULL,
  plaka      TEXT NOT NULL DEFAULT '',
  sofor_ad   TEXT NOT NULL DEFAULT '',
  sofor_tel  TEXT NOT NULL DEFAULT '',
  hostes_ad  TEXT NOT NULL DEFAULT '',
  hostes_tel TEXT NOT NULL DEFAULT '',
  kapasite   INTEGER NOT NULL DEFAULT 0,
  notu       TEXT NOT NULL DEFAULT '',
  aktif      INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER NOT NULL,
  UNIQUE (branch_id, ad)
);
CREATE TABLE IF NOT EXISTS servis_duraklari (
  id         INTEGER PRIMARY KEY,
  servis_id  INTEGER NOT NULL REFERENCES servisler(id) ON DELETE CASCADE,
  sira       INTEGER NOT NULL,
  ad         TEXT NOT NULL,
  sabah_saat TEXT NOT NULL DEFAULT '',
  aksam_saat TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS servis_durak_servis ON servis_duraklari (servis_id, sira);
CREATE TABLE IF NOT EXISTS servis_ogrenciler (
  student_membership_id INTEGER PRIMARY KEY REFERENCES memberships(id),
  servis_id             INTEGER NOT NULL REFERENCES servisler(id) ON DELETE CASCADE,
  durak_id              INTEGER REFERENCES servis_duraklari(id) ON DELETE SET NULL,
  yon                   TEXT NOT NULL DEFAULT 'cift',
  created_at            INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS servis_ogrenci_servis ON servis_ogrenciler (servis_id);
`);

const YONLER = { cift: 'Sabah ve akşam', sabah: 'Yalnız sabah', aksam: 'Yalnız akşam' };
const SINIR = { durak: 40, toplu: 60 };
const telNormalize = t => String(t || '').replace(/\D/g, '').slice(-10);
function telAl(v, ad) {
  if (!String(v ?? '').trim()) return '';
  const t = telNormalize(v);
  if (!/^[1-9]\d{9}$/.test(t)) throw new Hata(400, `${ad} geçerli değil (10 haneli, örn. 532 123 45 67)`);
  return t;
}
const plakaAl = v => String(v ?? '').toLocaleUpperCase('tr').replace(/[^0-9A-ZÇĞİÖŞÜ ]/g, '').replace(/\s+/g, ' ').trim().slice(0, 12);

function servisBul(o, id) {
  const s = db.prepare('SELECT * FROM servisler WHERE id = ?').get(tamSayi(id) || 0);
  if (!s || !kapsamdaMi(okulKapsami(o), s.branch_id)) throw new Hata(404, 'Servis bulunamadı');
  return s;
}
const duraklar = id => db.prepare('SELECT id, sira, ad, sabah_saat AS sabahSaat, aksam_saat AS aksamSaat FROM servis_duraklari WHERE servis_id = ? ORDER BY sira, id').all(id);

// Veli ve öğrenciye gösterilen servis bilgisi (öğrenciye bağlı)
function ogrenciServisi(ogrenciId) {
  const b = db.prepare('SELECT * FROM servis_ogrenciler WHERE student_membership_id = ?').get(ogrenciId);
  if (!b) return null;
  const s = db.prepare('SELECT * FROM servisler WHERE id = ?').get(b.servis_id);
  const d = b.durak_id ? db.prepare('SELECT * FROM servis_duraklari WHERE id = ?').get(b.durak_id) : null;
  return {
    servis: s.ad, plaka: s.plaka, aktif: !!s.aktif, soforAd: s.sofor_ad, soforTel: coz(s.sofor_tel), hostesAd: s.hostes_ad, hostesTel: coz(s.hostes_tel), notu: s.notu,
    yon: b.yon, yonAd: YONLER[b.yon], durak: d ? { ad: d.ad, sabahSaat: d.sabah_saat, aksamSaat: d.aksam_saat } : null,
  };
}

export async function servisApi({ req, res, url, o, json, govde, denetle }) {
  const yol = url.pathname;
  if (!yol.startsWith('/api/servis/')) return false;
  const yonetici = yonetimYetkisi(o, 'servis');
  try {
    // =============== Veli / öğrenci ===============
    if (req.method === 'GET' && yol === '/api/servis/benim') {
      if (o.role !== 'veli' && o.role !== 'ogrenci') throw new Hata(403, 'Bu işlem için yetkiniz yok');
      return json(res, 200, { ogrenciler: benimOgrencilerim(o).map(r => ({ id: r.id, ad: r.ad, sinif: r.sinif || '', servis: ogrenciServisi(r.id) })) }), true;
    }
    // Öğrenci dosyası: yönetim, sınıfın öğretmeni (yalnız araç/durak), veli, öğrenci
    if (req.method === 'GET' && yol === '/api/servis/ogrenci') {
      const ogr = ogrenciAl(o, url.searchParams.get('id'));
      if (ogr.iliski === 'yonetim' && !yonetici) throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const b = ogrenciServisi(ogr.id);
      if (b && ogr.iliski === 'ogretmen') { delete b.soforTel; delete b.hostesTel; }
      return json(res, 200, { ogrenci: { id: ogr.id, ad: ogr.ad }, servis: b }), true;
    }

    if (!yonetici) throw new Hata(403, 'Bu işlem için yetkiniz yok');

    // =============== Servis yönetimi ===============
    if (req.method === 'GET' && yol === '/api/servis/baglam') {
      const okullar = okullarim(o);
      return json(res, 200, { okullar, siniflar: db.prepare('SELECT id, name AS ad, branch_id AS okulId FROM classes ORDER BY name').all().filter(c => okullar.some(b => b.id === c.okulId)), yonler: YONLER }), true;
    }
    if (req.method === 'GET' && yol === '/api/servis/liste') {
      const okullar = okullarim(o).map(b => b.id);
      const yer = okullar.map(() => '?').join(',') || 'NULL';
      const okul = tamSayi(url.searchParams.get('okul'));
      const servisler = db.prepare(`SELECT s.*, b.name AS okul, (SELECT COUNT(*) FROM servis_ogrenciler so WHERE so.servis_id = s.id) AS dolu,
          (SELECT COUNT(*) FROM servis_duraklari d WHERE d.servis_id = s.id) AS durak
        FROM servisler s JOIN branches b ON b.id = s.branch_id WHERE s.branch_id IN (${yer}) ORDER BY s.aktif DESC, b.name, s.ad`).all(...okullar)
        .filter(s => !okul || s.branch_id === okul);
      const ogrenciler = kapsamOgrencileri(o, { okul });
      const bagli = new Set(db.prepare('SELECT student_membership_id AS id FROM servis_ogrenciler').all().map(r => r.id));
      return json(res, 200, {
        servisler: servisler.map(s => ({ id: s.id, okulId: s.branch_id, okul: s.okul, ad: s.ad, plaka: s.plaka, soforAd: s.sofor_ad, kapasite: s.kapasite, dolu: s.dolu, durak: s.durak, aktif: !!s.aktif })),
        toplam: { ogrenci: ogrenciler.length, servisli: ogrenciler.filter(r => bagli.has(r.id)).length, servissiz: ogrenciler.filter(r => !bagli.has(r.id)).length },
      }), true;
    }
    if (req.method === 'GET' && yol === '/api/servis/detay') {
      const s = servisBul(o, url.searchParams.get('id'));
      const d = duraklar(s.id);
      const ogrenciler = db.prepare(`SELECT so.student_membership_id AS id, so.durak_id AS durakId, so.yon, u.full_name AS ad, c.name AS sinif
        FROM servis_ogrenciler so JOIN memberships m ON m.id = so.student_membership_id JOIN users u ON u.id = m.user_id
        LEFT JOIN class_students cs ON cs.student_membership_id = m.id LEFT JOIN classes c ON c.id = cs.class_id
        WHERE so.servis_id = ? ORDER BY u.full_name`).all(s.id);
      const okul = db.prepare('SELECT name FROM branches WHERE id = ?').get(s.branch_id).name;
      return json(res, 200, {
        servis: { id: s.id, okulId: s.branch_id, okul, ad: s.ad, plaka: s.plaka, soforAd: s.sofor_ad, soforTel: coz(s.sofor_tel), hostesAd: s.hostes_ad, hostesTel: coz(s.hostes_tel), kapasite: s.kapasite, notu: s.notu, aktif: !!s.aktif },
        duraklar: d, ogrenciler,
      }), true;
    }
    if (req.method === 'POST' && yol === '/api/servis/kaydet') {
      const g = await govde(req);
      const ad = kisa(g.ad, 60);
      if (ad.length < 2) throw new Hata(400, 'Servis adını yazın (örn. Servis 1)');
      const kapasite = tamSayi(g.kapasite, 0, 200);
      if (kapasite === null) throw new Hata(400, 'Kapasite 0-200 arasında olmalı');
      const alanlar = [ad, plakaAl(g.plaka), kisa(g.soforAd, 80), sifrele(telAl(g.soforTel, 'Şoför telefonu')), kisa(g.hostesAd, 80), sifrele(telAl(g.hostesTel, 'Hostes telefonu')), kapasite, uzun(g.notu, 400), g.aktif === false ? 0 : 1];
      try {
        if (g.id) {
          const s = servisBul(o, g.id);
          const dolu = db.prepare('SELECT COUNT(*) AS n FROM servis_ogrenciler WHERE servis_id = ?').get(s.id).n;
          if (kapasite && kapasite < dolu) throw new Hata(409, `Serviste ${dolu} öğrenci var; kapasite bunun altına düşürülemez`);
          db.prepare('UPDATE servisler SET ad = ?, plaka = ?, sofor_ad = ?, sofor_tel = ?, hostes_ad = ?, hostes_tel = ?, kapasite = ?, notu = ?, aktif = ? WHERE id = ?').run(...alanlar, s.id);
          denetle(o.user_id, 'servis.guncelle', { servisId: s.id, ad });
          return json(res, 200, { tamam: true, id: s.id }), true;
        }
        const okulId = okulSec(o, g.okulId);
        const r = db.prepare('INSERT INTO servisler (ad, plaka, sofor_ad, sofor_tel, hostes_ad, hostes_tel, kapasite, notu, aktif, branch_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)')
          .run(...alanlar, okulId, Date.now());
        denetle(o.user_id, 'servis.ekle', { servisId: Number(r.lastInsertRowid), ad });
        return json(res, 200, { tamam: true, id: Number(r.lastInsertRowid) }), true;
      } catch (e) {
        if (String(e.message).includes('UNIQUE')) throw new Hata(409, 'Bu okulda aynı adlı bir servis var');
        throw e;
      }
    }
    if (req.method === 'POST' && yol === '/api/servis/sil') {
      const g = await govde(req);
      const s = servisBul(o, g.id);
      if (db.prepare('SELECT 1 FROM servis_ogrenciler WHERE servis_id = ?').get(s.id)) throw new Hata(409, 'Serviste öğrenci var; önce öğrencileri çıkarın ya da servisi pasif yapın');
      db.prepare('DELETE FROM servisler WHERE id = ?').run(s.id);
      denetle(o.user_id, 'servis.sil', { servisId: s.id, ad: s.ad });
      return json(res, 200, { tamam: true }), true;
    }

    // ---- Güzergâh durakları: sıralı tam liste gelir (id'si olan güncellenir, olmayan eklenir, gelmeyen silinir) ----
    if (req.method === 'POST' && yol === '/api/servis/duraklar') {
      const g = await govde(req);
      const s = servisBul(o, g.servisId);
      if (!Array.isArray(g.duraklar) || g.duraklar.length > SINIR.durak) throw new Hata(400, `En çok ${SINIR.durak} durak eklenebilir`);
      const liste = g.duraklar.map((d, i) => {
        const ad = kisa(d?.ad, 100);
        if (ad.length < 2) throw new Hata(400, `${i + 1}. durağın adını yazın`);
        const sabah = d?.sabahSaat || '', aksam = d?.aksamSaat || '';
        if ((sabah && !saatGecerli(sabah)) || (aksam && !saatGecerli(aksam))) throw new Hata(400, `${i + 1}. durağın saati geçersiz`);
        return { id: tamSayi(d?.id), ad, sabah, aksam };
      });
      const mevcut = new Set(duraklar(s.id).map(d => d.id));
      if (liste.some(d => d.id && !mevcut.has(d.id))) throw new Hata(400, 'Durak bu servise ait değil');
      islem(() => {
        const kalan = new Set(liste.filter(d => d.id).map(d => d.id));
        for (const id of mevcut) if (!kalan.has(id)) db.prepare('DELETE FROM servis_duraklari WHERE id = ?').run(id);
        liste.forEach((d, i) => {
          if (d.id) db.prepare('UPDATE servis_duraklari SET sira = ?, ad = ?, sabah_saat = ?, aksam_saat = ? WHERE id = ?').run(i + 1, d.ad, d.sabah, d.aksam, d.id);
          else db.prepare('INSERT INTO servis_duraklari (servis_id, sira, ad, sabah_saat, aksam_saat) VALUES (?,?,?,?,?)').run(s.id, i + 1, d.ad, d.sabah, d.aksam);
        });
      });
      denetle(o.user_id, 'servis.duraklar', { servisId: s.id, adet: liste.length });
      return json(res, 200, { tamam: true, duraklar: duraklar(s.id) }), true;
    }

    // ---- Servise bağlama ----
    if (req.method === 'GET' && yol === '/api/servis/servissizler') {
      const okul = tamSayi(url.searchParams.get('okul'));
      const bagli = new Set(db.prepare('SELECT student_membership_id AS id FROM servis_ogrenciler').all().map(r => r.id));
      const liste = kapsamOgrencileri(o, { okul, sinif: url.searchParams.get('sinif'), ara: url.searchParams.get('ara') }).filter(r => !bagli.has(r.id)).slice(0, 300);
      return json(res, 200, { ogrenciler: liste.map(r => ({ id: r.id, ad: r.ad, sinif: r.sinif || '', okulId: r.subeId })) }), true;
    }
    if (req.method === 'POST' && yol === '/api/servis/ata') {
      const g = await govde(req);
      const s = servisBul(o, g.servisId);
      if (!s.aktif) throw new Hata(409, 'Servis pasif; öğrenci eklenemez');
      const ids = [...new Set((Array.isArray(g.ogrenciIds) ? g.ogrenciIds : []).map(Number))];
      if (!ids.length || ids.length > SINIR.toplu) throw new Hata(400, `Bir seferde 1-${SINIR.toplu} öğrenci seçin`);
      const yon = Object.hasOwn(YONLER, g.yon) ? g.yon : 'cift';
      let durakId = null;
      if (g.durakId) {
        durakId = tamSayi(g.durakId);
        if (!durakId || !db.prepare('SELECT 1 FROM servis_duraklari WHERE id = ? AND servis_id = ?').get(durakId, s.id)) throw new Hata(400, 'Durak bu servise ait değil');
      }
      for (const id of ids) {
        const ogr = ogrenciAl(o, id);
        if (ogr.iliski !== 'yonetim' || ogr.subeId !== s.branch_id) throw new Hata(400, `${ogr.ad} bu servisin okulunda değil`);
        if (ogr.durum !== 'aktif') throw new Hata(400, `${ogr.ad} aktif öğrenci değil`);
      }
      const yeni = ids.filter(id => !db.prepare('SELECT 1 FROM servis_ogrenciler WHERE student_membership_id = ? AND servis_id = ?').get(id, s.id)).length;
      const dolu = db.prepare('SELECT COUNT(*) AS n FROM servis_ogrenciler WHERE servis_id = ?').get(s.id).n;
      if (s.kapasite && dolu + yeni > s.kapasite) throw new Hata(409, `Kapasite yetersiz: ${s.kapasite} kişilik serviste ${dolu} öğrenci var, ${yeni} eklenmek isteniyor`);
      islem(() => {
        for (const id of ids) {
          db.prepare(`INSERT INTO servis_ogrenciler (student_membership_id, servis_id, durak_id, yon, created_at) VALUES (?,?,?,?,?)
            ON CONFLICT (student_membership_id) DO UPDATE SET servis_id = excluded.servis_id, durak_id = excluded.durak_id, yon = excluded.yon, created_at = excluded.created_at`)
            .run(id, s.id, durakId, yon, Date.now());
        }
      });
      denetle(o.user_id, 'servis.ata', { servisId: s.id, ogrenciler: ids });
      return json(res, 200, { tamam: true, eklenen: ids.length }), true;
    }
    // Servis içindeki öğrencinin durak / yön bilgisini değiştirir
    if (req.method === 'POST' && yol === '/api/servis/ogrenci-guncelle') {
      const g = await govde(req);
      const ogr = ogrenciAl(o, g.ogrenciId);
      const b = db.prepare('SELECT * FROM servis_ogrenciler WHERE student_membership_id = ?').get(ogr.id);
      if (ogr.iliski !== 'yonetim' || !b) throw new Hata(404, 'Servis kaydı bulunamadı');
      servisBul(o, b.servis_id);
      const durakId = g.durakId ? tamSayi(g.durakId) : null;
      if (g.durakId && (!durakId || !db.prepare('SELECT 1 FROM servis_duraklari WHERE id = ? AND servis_id = ?').get(durakId, b.servis_id))) throw new Hata(400, 'Durak bu servise ait değil');
      const yon = Object.hasOwn(YONLER, g.yon) ? g.yon : b.yon;
      db.prepare('UPDATE servis_ogrenciler SET durak_id = ?, yon = ? WHERE student_membership_id = ?').run(durakId, yon, ogr.id);
      denetle(o.user_id, 'servis.ogrenci-guncelle', { ogrenciId: ogr.id, servisId: b.servis_id });
      return json(res, 200, { tamam: true }), true;
    }
    if (req.method === 'POST' && yol === '/api/servis/cikar') {
      const g = await govde(req);
      const ogr = ogrenciAl(o, g.ogrenciId);
      if (ogr.iliski !== 'yonetim') throw new Hata(404, 'Öğrenci bulunamadı');
      const b = db.prepare('SELECT * FROM servis_ogrenciler WHERE student_membership_id = ?').get(ogr.id);
      if (!b) throw new Hata(404, 'Öğrenci bir servise bağlı değil');
      servisBul(o, b.servis_id);
      db.prepare('DELETE FROM servis_ogrenciler WHERE student_membership_id = ?').run(ogr.id);
      denetle(o.user_id, 'servis.cikar', { ogrenciId: ogr.id, servisId: b.servis_id });
      return json(res, 200, { tamam: true }), true;
    }
  } catch (e) { return hataYanit(res, json, e); }
  return false;
}
