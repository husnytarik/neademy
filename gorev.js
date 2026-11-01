import { db } from './db.js';
import { DERS_ZAMANLARI, GUN_ADLARI, gunAcik } from './okul-ayar.js';

// Öğretmenin çalışma saatleri (müsait olmadığı saatler, haftalık ders yükü) ve nöbet / görevlendirmeler.
// Görev haftalık tekrar eder (gün + saatler) ya da belirli bir tarihe özeldir.
db.exec(`
CREATE TABLE IF NOT EXISTS ogretmen_kapali (
  user_id INTEGER NOT NULL REFERENCES users(id),
  day     INTEGER NOT NULL,
  period  INTEGER NOT NULL,
  PRIMARY KEY (user_id, day, period)
);
CREATE TABLE IF NOT EXISTS ogretmen_ayar (
  user_id       INTEGER PRIMARY KEY REFERENCES users(id),
  haftalik_azami INTEGER
);
CREATE TABLE IF NOT EXISTS gorevler (
  id      INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  tur     TEXT NOT NULL CHECK (tur IN ('nobet','gorev')),
  ad      TEXT NOT NULL,
  yer     TEXT NOT NULL DEFAULT '',
  tekrar  TEXT NOT NULL CHECK (tekrar IN ('haftalik','tek')),
  day     INTEGER,
  tarih   TEXT,
  saatler TEXT NOT NULL
)`);
// Görev saati serbest aralıktır (teneffüs ya da ders başlamadan önce olabilir); saatler = aralığa değen ders saatleri
for (const s of ['bas', 'bit']) {
  if (!db.prepare('PRAGMA table_info(gorevler)').all().some(k => k.name === s)) db.exec(`ALTER TABLE gorevler ADD COLUMN ${s} TEXT`);
}

const tamSayi = (v, min, max) => {
  const n = Number(v);
  return Number.isInteger(n) && n >= min && n <= max ? n : null;
};
const TARIH = /^\d{4}-\d{2}-\d{2}$/;
const gunNo = tarih => new Date(tarih + 'T00:00:00Z').getUTCDay();
const saatListesi = g => { try { return JSON.parse(g.saatler); } catch { return []; } };
const SAAT = /^([01]\d|2[0-3]):[0-5]\d$/;
const dk = s => Number(s.slice(0, 2)) * 60 + Number(s.slice(3, 5));
// Zaman aralığına değen ders saatleri (1'den başlar)
const kesisenDersler = (bas, bit) => DERS_ZAMANLARI.map((z, i) => [i + 1, z])
  .filter(([, z]) => dk(z[0]) < dk(bit) && dk(z[1]) > dk(bas)).map(([i]) => i);
// Eski kayıtlarda saat aralığı yoktur: ders saatlerinden türetilir
export function gorevAraligi(g) {
  if (g.bas && g.bit) return [g.bas, g.bit];
  const s = saatListesi(g);
  if (!s.length) return null;
  const ilk = DERS_ZAMANLARI[Math.min(...s) - 1], son = DERS_ZAMANLARI[Math.max(...s) - 1];
  return ilk && son ? [ilk[0], son[1]] : null;
}

// Öğretmen bu gün/saatte derse konamaz mı? Neden varsa metin, yoksa null
export function ogretmenMesgulNedeni(userId, gun, saat) {
  if (db.prepare('SELECT 1 FROM ogretmen_kapali WHERE user_id = ? AND day = ? AND period = ?').get(userId, gun, saat)) {
    return 'Öğretmen bu saatte müsait değil';
  }
  const g = db.prepare("SELECT * FROM gorevler WHERE user_id = ? AND tekrar = 'haftalik' AND day = ?").all(userId, gun)
    .find(x => saatListesi(x).includes(saat));
  return g ? `Öğretmenin bu saatte ${g.tur === 'nobet' ? 'nöbeti' : 'görevi'} var (${g.ad})` : null;
}

// Haftalık düzende bu öğretmenin derse atanmış gün/saatleri
const dersSaatleri = userId => db.prepare(`
  SELECT s.day, s.period, c.name AS sinif FROM schedule s
  JOIN assignments a ON a.id = s.assignment_id
  JOIN memberships m ON m.id = a.teacher_membership_id
  JOIN classes c ON c.id = s.class_id
  WHERE m.user_id = ?`).all(userId);

const gorevSatiri = g => ({
  id: g.id, userId: g.user_id, tur: g.tur, ad: g.ad, yer: g.yer, tekrar: g.tekrar,
  gun: g.day, tarih: g.tarih, saatler: saatListesi(g),
  bas: gorevAraligi(g)?.[0] || null, bit: gorevAraligi(g)?.[1] || null,
});

export async function gorevApi({ req, res, url, o, json, govde, denetle }) {
  const yol = url.pathname;
  const hata = (kod, mesaj) => { json(res, kod, { hata: mesaj }); return true; };
  const ogretmenMi = id => !!id && !!db.prepare("SELECT 1 FROM memberships WHERE user_id = ? AND role = 'ogretmen' AND status = 'aktif'").get(id);

  if (req.method === 'GET' && yol === '/api/yonetim/ogretmen-durum') {
    const userId = tamSayi(url.searchParams.get('userId'), 1, 1e9);
    if (!userId) return hata(400, 'Öğretmen seçiniz');
    json(res, 200, {
      kapali: db.prepare('SELECT day AS gun, period AS saat FROM ogretmen_kapali WHERE user_id = ?').all(userId),
      azami: db.prepare('SELECT haftalik_azami AS azami FROM ogretmen_ayar WHERE user_id = ?').get(userId)?.azami ?? null,
      gorevler: db.prepare('SELECT * FROM gorevler WHERE user_id = ? ORDER BY tekrar, day, tarih').all(userId).map(gorevSatiri),
    });
    return true;
  }

  if (req.method === 'GET' && yol === '/api/yonetim/gorevler') {
    json(res, 200, {
      gorevler: db.prepare(`SELECT g.*, u.full_name AS ogretmen FROM gorevler g JOIN users u ON u.id = g.user_id
                            ORDER BY g.tur, g.tekrar, g.day, g.tarih, u.full_name`).all()
        .map(g => ({ ...gorevSatiri(g), ogretmen: g.ogretmen })),
    });
    return true;
  }

  if (req.method !== 'POST' || !['/api/yonetim/ogretmen-musait', '/api/yonetim/gorev-kaydet', '/api/yonetim/gorev-sil'].includes(yol)) return false;
  const b = await govde(req);

  // Müsait olunmayan saatler + haftalık ders yükü (tümü birden kaydedilir)
  if (yol === '/api/yonetim/ogretmen-musait') {
    const userId = tamSayi(b.userId, 1, 1e9);
    if (!ogretmenMi(userId)) return hata(404, 'Öğretmen bulunamadı');
    const kapali = [];
    for (const k of Array.isArray(b.kapali) ? b.kapali : []) {
      const gun = Number(k?.gun), saat = tamSayi(k?.saat, 1, DERS_ZAMANLARI.length);
      if (!Number.isInteger(gun) || !gunAcik(gun) || !saat) return hata(400, 'Geçersiz gün veya ders saati');
      if (!kapali.some(x => x.gun === gun && x.saat === saat)) kapali.push({ gun, saat });
    }
    const azami = b.azami === null || b.azami === '' || b.azami === undefined ? null : tamSayi(b.azami, 1, 80);
    if (b.azami !== null && b.azami !== '' && b.azami !== undefined && azami === null) return hata(400, 'Haftalık ders yükü 1-80 olmalı');
    const dolu = dersSaatleri(userId).find(d => kapali.some(k => k.gun === d.day && k.saat === d.period));
    if (dolu) return hata(409, `${GUN_ADLARI[dolu.day]} ${dolu.period}. saatte ${dolu.sinif} dersi var; önce programdan çıkarın`);
    db.exec('BEGIN');
    try {
      db.prepare('DELETE FROM ogretmen_kapali WHERE user_id = ?').run(userId);
      const ekle = db.prepare('INSERT INTO ogretmen_kapali (user_id, day, period) VALUES (?,?,?)');
      for (const k of kapali) ekle.run(userId, k.gun, k.saat);
      db.prepare(`INSERT INTO ogretmen_ayar (user_id, haftalik_azami) VALUES (?, ?)
                  ON CONFLICT (user_id) DO UPDATE SET haftalik_azami = excluded.haftalik_azami`).run(userId, azami);
      db.exec('COMMIT');
    } catch (e) { db.exec('ROLLBACK'); throw e; }
    denetle(o.user_id, 'ogretmen-musait', { userId, kapali: kapali.length, azami });
    json(res, 200, { tamam: true });
    return true;
  }

  if (yol === '/api/yonetim/gorev-sil') {
    const id = tamSayi(b.id, 1, 1e9);
    if (!id || !db.prepare('SELECT 1 FROM gorevler WHERE id = ?').get(id)) return hata(404, 'Görev bulunamadı');
    db.prepare('DELETE FROM gorevler WHERE id = ?').run(id);
    denetle(o.user_id, 'gorev-sil', { id });
    json(res, 200, { tamam: true });
    return true;
  }

  // Nöbet / görevlendirme ekle ya da düzenle (haftalık görev birden fazla güne aynı anda verilebilir)
  const userId = tamSayi(b.userId, 1, 1e9);
  if (!ogretmenMi(userId)) return hata(404, 'Öğretmen bulunamadı');
  if (!['nobet', 'gorev'].includes(b.tur)) return hata(400, 'Tür seçiniz');
  const ad = String(b.ad || '').trim();
  const yer = String(b.yer || '').trim();
  if (ad.length < 2 || ad.length > 60) return hata(400, 'Görev adı 2-60 karakter olmalı');
  if (yer.length > 60) return hata(400, 'Yer en çok 60 karakter olabilir');
  const saatHatasi = (bas, bit) => {
    if (!SAAT.test(bas) || !SAAT.test(bit)) return 'Başlangıç ve bitiş saatini giriniz';
    if (dk(bit) <= dk(bas)) return 'Bitiş saati başlangıçtan sonra olmalı';
    return null;
  };
  // Her gün kendi saat aralığına sahip olabilir: kalemler = [{ gun, bas, bit, saatler }]
  const kalemler = [];
  let tarih = null;
  if (b.tekrar === 'haftalik') {
    const ham = Array.isArray(b.gunler) ? b.gunler : [{ gun: b.gun }];
    for (const x of ham) {
      const nesne = x && typeof x === 'object';
      const gun = Number(nesne ? x.gun : x);
      if (!Number.isInteger(gun) || !gunAcik(gun)) return hata(400, 'Okul günlerinden seçiniz');
      if (kalemler.some(k => k.gun === gun)) continue;
      const bas = String((nesne && x.bas) || b.bas || ''), bit = String((nesne && x.bit) || b.bit || '');
      const h = saatHatasi(bas, bit);
      if (h) return hata(400, `${GUN_ADLARI[gun]}: ${h}`);
      kalemler.push({ gun, bas, bit });
    }
    if (!kalemler.length) return hata(400, 'En az bir gün seçiniz');
  } else if (b.tekrar === 'tek') {
    tarih = String(b.tarih || '');
    if (!TARIH.test(tarih) || Number.isNaN(Date.parse(tarih))) return hata(400, 'Geçerli bir tarih giriniz');
    const gun = gunNo(tarih);
    if (!gunAcik(gun)) return hata(400, 'Seçilen tarih okul günü değil');
    const bas = String(b.bas || ''), bit = String(b.bit || '');
    const h = saatHatasi(bas, bit);
    if (h) return hata(400, h);
    kalemler.push({ gun, bas, bit });
  } else return hata(400, 'Tekrar türünü seçiniz');
  for (const k of kalemler) k.saatler = kesisenDersler(k.bas, k.bit);

  const id = b.id ? tamSayi(b.id, 1, 1e9) : null;
  const mevcut = id ? db.prepare('SELECT * FROM gorevler WHERE id = ?').get(id) : null;
  if (b.id && !mevcut) return hata(404, 'Görev bulunamadı');

  // Çakışma: ders programı, müsait olmadığı saat ve aynı gün/saatteki başka görev
  const dersler = dersSaatleri(userId);
  for (const k of kalemler) {
    for (const s of k.saatler) {
      if (db.prepare('SELECT 1 FROM ogretmen_kapali WHERE user_id = ? AND day = ? AND period = ?').get(userId, k.gun, s)) {
        return hata(409, `${GUN_ADLARI[k.gun]} ${s}. saatte öğretmen müsait değil`);
      }
      const ders = dersler.find(d => d.day === k.gun && d.period === s);
      if (ders) return hata(409, `${GUN_ADLARI[k.gun]} ${s}. saatte ${ders.sinif} dersi var`);
    }
    const digerleri = db.prepare('SELECT * FROM gorevler WHERE user_id = ? AND day = ? AND id IS NOT ?').all(userId, k.gun, id)
      .filter(x => x.tekrar === 'haftalik' || b.tekrar === 'haftalik' || x.tarih === tarih);
    const cakisan = digerleri.find(x => {
      const ar = gorevAraligi(x);
      return ar && dk(ar[0]) < dk(k.bit) && dk(ar[1]) > dk(k.bas);
    });
    if (cakisan) return hata(409, `${GUN_ADLARI[k.gun]} günü aynı saatte başka bir görev var (${cakisan.ad})`);
  }

  // Düzenlenen kayıt, seçilen günlerden kendi gününü korur; kalan günler yeni kayıt olur
  const sirali = mevcut && kalemler.some(k => k.gun === mevcut.day) ? [kalemler.find(k => k.gun === mevcut.day), ...kalemler.filter(k => k.gun !== mevcut.day)] : kalemler;
  const idler = [];
  db.exec('BEGIN');
  try {
    sirali.forEach((k, i) => {
      const alanlar = [userId, b.tur, ad, yer, b.tekrar, k.gun, tarih, JSON.stringify(k.saatler), k.bas, k.bit];
      if (id && i === 0) {
        db.prepare('UPDATE gorevler SET user_id=?, tur=?, ad=?, yer=?, tekrar=?, day=?, tarih=?, saatler=?, bas=?, bit=? WHERE id=?').run(...alanlar, id);
        idler.push(id);
      } else {
        idler.push(Number(db.prepare('INSERT INTO gorevler (user_id, tur, ad, yer, tekrar, day, tarih, saatler, bas, bit) VALUES (?,?,?,?,?,?,?,?,?,?)').run(...alanlar).lastInsertRowid));
      }
    });
    db.exec('COMMIT');
  } catch (e) { db.exec('ROLLBACK'); throw e; }
  denetle(o.user_id, id ? 'gorev-duzenle' : 'gorev-ekle', { ids: idler, userId, tur: b.tur, ad, tekrar: b.tekrar, gunler: sirali.map(k => k.gun) });
  json(res, id ? 200 : 201, { tamam: true, id: idler[0], sayi: idler.length });
  return true;
}
