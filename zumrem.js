import { db } from './db.js';
import { kisiRolleri } from './yetki.js';
import { KULUP_DERSI } from './ders-programi.js';
import { tarihAcik } from './tatil.js';

// Zümre = bir okuldaki aynı branşın öğretmenleri. Her öğretmenin tek branşı vardır (üyelikte brans_id, bir ders kaydı);
// verdiği dersler birden çok olabilir. Zümre başkanı ayrı profil değildir: öğretmen üyeliğinde zumre_baskani işaretlidir ve
// her okul + branş için en fazla bir kişidir. Toplantıyı yalnızca başkan kurar; yazı tüm zümre öğretmenlerinindir.
db.exec(`
CREATE TABLE IF NOT EXISTS zumre_toplantilari (
  id                     INTEGER PRIMARY KEY,
  branch_id              INTEGER NOT NULL REFERENCES branches(id),
  course_id              INTEGER NOT NULL REFERENCES courses(id),
  baslik                 TEXT NOT NULL,
  tekrar                 TEXT NOT NULL CHECK (tekrar IN ('yok','haftalik','2haftalik','aylik')),
  baslangic              TEXT NOT NULL,
  saat                   TEXT NOT NULL,
  yer                    TEXT NOT NULL DEFAULT '',
  gundem                 TEXT NOT NULL DEFAULT '',
  olusturan_membership_id INTEGER NOT NULL REFERENCES memberships(id),
  created_at             INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS zumre_iletileri (
  id            INTEGER PRIMARY KEY,
  branch_id     INTEGER NOT NULL REFERENCES branches(id),
  course_id     INTEGER NOT NULL REFERENCES courses(id),
  membership_id INTEGER NOT NULL REFERENCES memberships(id),
  metin         TEXT NOT NULL,
  created_at    INTEGER NOT NULL
);
-- Toplantıda alınan kararlar: toplantının o günkü kaydı (toplantı silinse de kayıt kalır, bu yüzden başlık/saat/yer kopyalanır)
CREATE TABLE IF NOT EXISTS zumre_toplanti_kararlari (
  id                  INTEGER PRIMARY KEY,
  branch_id           INTEGER NOT NULL REFERENCES branches(id),
  course_id           INTEGER NOT NULL REFERENCES courses(id),
  toplanti_id         INTEGER,
  baslik              TEXT NOT NULL,
  tarih               TEXT NOT NULL,
  saat                TEXT NOT NULL,
  yer                 TEXT NOT NULL DEFAULT '',
  karar               TEXT NOT NULL,
  yazan_membership_id INTEGER NOT NULL REFERENCES memberships(id),
  created_at          INTEGER NOT NULL,
  guncellendi         INTEGER
);
CREATE UNIQUE INDEX IF NOT EXISTS zumre_karar_tek ON zumre_toplanti_kararlari (toplanti_id, tarih);
-- Yönetimin kurduğu zümre başkanları toplantısı (tek seferlik, okul bazlı); kararı yalnızca yönetim ve o okulun başkanları görür
CREATE TABLE IF NOT EXISTS baskan_toplantilari (
  id                  INTEGER PRIMARY KEY,
  branch_id           INTEGER NOT NULL REFERENCES branches(id),
  baslik              TEXT NOT NULL,
  tarih               TEXT NOT NULL,
  saat                TEXT NOT NULL,
  yer                 TEXT NOT NULL DEFAULT '',
  gundem              TEXT NOT NULL DEFAULT '',
  karar               TEXT NOT NULL DEFAULT '',
  karar_yazan_user_id INTEGER REFERENCES users(id),
  karar_zamani        INTEGER,
  olusturan_user_id   INTEGER NOT NULL REFERENCES users(id),
  created_at          INTEGER NOT NULL
);
-- Toplantıya katılan okullar (birden fazla olabilir); baskan_toplantilari.branch_id ilk okuldur
CREATE TABLE IF NOT EXISTS baskan_toplanti_okullari (
  toplanti_id INTEGER NOT NULL REFERENCES baskan_toplantilari(id) ON DELETE CASCADE,
  branch_id   INTEGER NOT NULL REFERENCES branches(id),
  PRIMARY KEY (toplanti_id, branch_id)
);
INSERT OR IGNORE INTO baskan_toplanti_okullari (toplanti_id, branch_id) SELECT id, branch_id FROM baskan_toplantilari;`);

export const TEKRAR = { yok: 'Tek seferlik', haftalik: 'Her hafta', '2haftalik': 'İki haftada bir', aylik: 'Ayda bir' };
const HATIRLATMA_GUN = 2;
const ILETI_SINIRI = 60;
const KARAR_SINIRI = 50;

const tamSayi = v => { const n = Number(v); return Number.isInteger(n) && n > 0 ? n : null; };
const metin = (v, en) => String(v ?? '').trim().slice(0, en);
const trTarih = (d = new Date()) => d.toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
const trSaat = (d = new Date()) => d.toLocaleTimeString('sv-SE', { timeZone: 'Europe/Istanbul', hour: '2-digit', minute: '2-digit' });
const tarihGecerli = t => /^\d{4}-\d{2}-\d{2}$/.test(t) && !Number.isNaN(Date.parse(t + 'T00:00:00Z')) && new Date(t + 'T00:00:00Z').toISOString().slice(0, 10) === t;
const gunEkle = (t, n) => { const d = new Date(t + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
function ayEkle(t, n) {
  const [y, a, g] = t.split('-').map(Number);
  const hedef = new Date(Date.UTC(y, a - 1 + n, 1));
  const son = new Date(Date.UTC(hedef.getUTCFullYear(), hedef.getUTCMonth() + 1, 0)).getUTCDate();
  hedef.setUTCDate(Math.min(g, son));
  return hedef.toISOString().slice(0, 10);
}

// Bugünden (saati geçmediyse bugün dahil) başlayarak toplantının sıradaki tarihleri. Haftalık toplantılar tatile düşerse o hafta atlanır;
// aylık toplantı kapalı güne (hafta sonu, tatil) düşerse sonraki okul gününe kayar.
export function siradakiler(t, adet, simdi = new Date()) {
  const bugun = trTarih(simdi), saat = trSaat(simdi);
  const gelecekMi = d => d > bugun || (d === bugun && t.saat >= saat);
  if (t.tekrar === 'yok') return gelecekMi(t.baslangic) ? [t.baslangic] : [];
  const sonuc = [];
  let d = t.baslangic;
  for (let i = 0; i < 800 && sonuc.length < adet; i++) {
    let g = d;
    if (t.tekrar === 'aylik') for (let k = 0; k < 10 && !tarihAcik(g); k++) g = gunEkle(g, 1);
    if (gelecekMi(g) && tarihAcik(g)) sonuc.push(g);
    d = t.tekrar === 'aylik' ? ayEkle(t.baslangic, i + 1) : gunEkle(d, t.tekrar === 'haftalik' ? 7 : 14);
  }
  return sonuc;
}

// Toplantının şimdiye kadar yapılmış (saati gelmiş) tarihleri; siradakiler ile aynı kurallarla, eskiden yeniye
export function gerceklesenler(t, simdi = new Date()) {
  const bugun = trTarih(simdi), saat = trSaat(simdi);
  const basladi = d => d < bugun || (d === bugun && t.saat <= saat);
  if (t.tekrar === 'yok') return basladi(t.baslangic) ? [t.baslangic] : [];
  const sonuc = [];
  let d = t.baslangic;
  for (let i = 0; i < 800 && d <= bugun; i++) {
    let g = d;
    if (t.tekrar === 'aylik') for (let k = 0; k < 10 && !tarihAcik(g); k++) g = gunEkle(g, 1);
    if (basladi(g) && tarihAcik(g)) sonuc.push(g);
    d = t.tekrar === 'aylik' ? ayEkle(t.baslangic, i + 1) : gunEkle(d, t.tekrar === 'haftalik' ? 7 : 14);
  }
  return sonuc;
}

// ---- Branş ve zümre başkanlığı: öğretmen üyeliğinde durur ----
// Branşı olmayan öğretmenlere, verebildiği derslerden en çok ders saati olanı (eşitse ilki) varsayılan branş yapar
export function bransVarsayilanlari() {
  const sec = db.prepare(`SELECT tc.course_id FROM teacher_courses tc JOIN courses co ON co.id = tc.course_id
    WHERE tc.teacher_membership_id = ? AND co.name <> ?
    ORDER BY (SELECT COALESCE(SUM(a.weekly_hours), 0) FROM assignments a WHERE a.teacher_membership_id = tc.teacher_membership_id AND a.course_id = tc.course_id) DESC, tc.course_id LIMIT 1`);
  const yaz = db.prepare('UPDATE memberships SET brans_id = ? WHERE id = ?');
  for (const m of db.prepare("SELECT id FROM memberships WHERE role = 'ogretmen' AND brans_id IS NULL").all()) {
    const d = sec.get(m.id, KULUP_DERSI);
    if (d) yaz.run(d.course_id, m.id);
  }
}

// "Zümre başkanı" rolü (yetkiler için), yalnızca üyeliğinde başkan işareti olanlarda bulunur
export function zumreRolunuEsitle() {
  const r = db.prepare("SELECT id FROM roller WHERE kod = 'zumre'").get();
  if (!r) return;
  db.prepare('DELETE FROM kullanici_roller WHERE rol_id = ? AND user_id NOT IN (SELECT user_id FROM memberships WHERE zumre_baskani = 1)').run(r.id);
  db.prepare('INSERT OR IGNORE INTO kullanici_roller (user_id, rol_id) SELECT DISTINCT user_id, ? FROM memberships WHERE zumre_baskani = 1').run(r.id);
}

// Başkanlığı verir (aynı okul + branştaki eski başkandan alır) ya da alır; hata varsa metin döner
export function zumreBaskaniAyarla(uyelikId, ver) {
  const m = db.prepare("SELECT id, branch_id, brans_id FROM memberships WHERE id = ? AND role = 'ogretmen' AND status = 'aktif'").get(uyelikId);
  if (!m) return 'Aktif öğretmenlik üyeliği bulunamadı';
  if (ver) {
    if (!m.brans_id) return 'Önce branş seçin';
    db.prepare('UPDATE memberships SET zumre_baskani = 0 WHERE branch_id = ? AND brans_id = ? AND zumre_baskani = 1').run(m.branch_id, m.brans_id);
  }
  db.prepare('UPDATE memberships SET zumre_baskani = ? WHERE id = ?').run(ver ? 1 : 0, m.id);
  zumreRolunuEsitle();
  return null;
}

if (!db.prepare('PRAGMA table_info(memberships)').all().some(c => c.name === 'brans_id')) {
  db.exec('BEGIN'); // yarım kalırsa sütunlar da geri alınır, taşıma bir sonraki açılışta baştan çalışır
  db.exec('ALTER TABLE memberships ADD COLUMN brans_id INTEGER REFERENCES courses(id)');
  db.exec('ALTER TABLE memberships ADD COLUMN zumre_baskani INTEGER NOT NULL DEFAULT 0');
  bransVarsayilanlari();
  // Eski kullanıcı düzeyindeki "Zümre başkanı" rolü: her okul + branşta en eski üyelik başkan kalır
  const eskiBaskan = "SELECT kr.user_id FROM kullanici_roller kr JOIN roller r ON r.id = kr.rol_id WHERE r.kod = 'zumre'";
  db.exec(`UPDATE memberships SET zumre_baskani = 1 WHERE role = 'ogretmen' AND brans_id IS NOT NULL AND user_id IN (${eskiBaskan})
    AND id = (SELECT MIN(m2.id) FROM memberships m2 WHERE m2.role = 'ogretmen' AND m2.branch_id = memberships.branch_id
              AND m2.brans_id = memberships.brans_id AND m2.user_id IN (${eskiBaskan}))`);
  db.exec('COMMIT');
}
bransVarsayilanlari();
zumreRolunuEsitle();

// Öğretmenin zümresi: kendi okulundaki branşı (tek)
function zumreler(uyelikId) {
  return db.prepare(`SELECT co.id, co.name AS ad, m.branch_id AS sube FROM memberships m JOIN courses co ON co.id = m.brans_id
    WHERE m.id = ? AND co.name <> ?`).all(uyelikId, KULUP_DERSI);
}

function uyeler(sube, dersId, benimId) {
  return db.prepare(`SELECT m.id, u.full_name AS ad, u.phone AS telefon, m.zumre_baskani AS baskan
    FROM memberships m JOIN users u ON u.id = m.user_id
    WHERE m.role = 'ogretmen' AND m.status = 'aktif' AND m.branch_id = ?
      AND m.brans_id = ?
    ORDER BY baskan DESC, u.full_name`).all(sube, dersId).map(r => ({ id: r.id, ad: r.ad, telefon: r.telefon, baskan: !!r.baskan, ben: r.id === benimId }));
}

const baskanMi = (uyelikId) => !!db.prepare('SELECT 1 FROM memberships WHERE id = ? AND zumre_baskani = 1').get(uyelikId);

// Toplantı hatırlatmaları: önümüzdeki günlerde olan zümre toplantıları (öğretmen paneli)
export function zumreHatirlatmalari(uyelikId) {
  const bugun = trTarih();
  const sinir = gunEkle(bugun, HATIRLATMA_GUN);
  const liste = [];
  for (const z of zumreler(uyelikId)) {
    for (const t of db.prepare('SELECT * FROM zumre_toplantilari WHERE branch_id = ? AND course_id = ?').all(z.sube, z.id)) {
      const [tarih] = siradakiler(t, 1);
      if (tarih && tarih <= sinir) liste.push({ baslik: t.baslik, zumre: z.ad, courseId: z.id, tarih, saat: t.saat, yer: t.yer, kalanGun: Math.round((Date.parse(tarih) - Date.parse(bugun)) / 86400000) });
    }
  }
  // Zümre başkanıysa okulundaki başkanlar toplantıları da hatırlatılır
  const uye = db.prepare('SELECT branch_id, zumre_baskani FROM memberships WHERE id = ?').get(uyelikId);
  if (uye?.zumre_baskani) {
    const simdi = trSaat();
    for (const t of db.prepare('SELECT t.* FROM baskan_toplantilari t WHERE t.id IN (SELECT toplanti_id FROM baskan_toplanti_okullari WHERE branch_id = ?) AND t.tarih >= ? AND t.tarih <= ?').all(uye.branch_id, bugun, sinir)) {
      if (t.tarih === bugun && t.saat < simdi) continue;
      liste.push({ baslik: t.baslik, zumre: 'Zümre başkanları', courseId: null, baskanlar: true, tarih: t.tarih, saat: t.saat, yer: t.yer, kalanGun: Math.round((Date.parse(t.tarih) - Date.parse(bugun)) / 86400000) });
    }
  }
  return liste.sort((a, b) => (a.tarih + a.saat).localeCompare(b.tarih + b.saat));
}

// Öğretmenin belirli tarih aralığındaki toplantıları (takvim): zümre toplantıları ve zümre başkanıysa başkanlar toplantıları
function aralikTarihleri(t, bas, bit) {
  if (t.tekrar === 'yok') return t.baslangic >= bas && t.baslangic <= bit && tarihAcik(t.baslangic) ? [t.baslangic] : [];
  const sonuc = [];
  let d = t.baslangic;
  for (let i = 0; i < 800 && d <= bit; i++) {
    let g = d;
    if (t.tekrar === 'aylik') for (let k = 0; k < 10 && !tarihAcik(g); k++) g = gunEkle(g, 1);
    if (g >= bas && g <= bit && tarihAcik(g)) sonuc.push(g);
    d = t.tekrar === 'aylik' ? ayEkle(t.baslangic, i + 1) : gunEkle(d, t.tekrar === 'haftalik' ? 7 : 14);
  }
  return sonuc;
}

export function ogretmenToplantilari(uyelikId, bas, bit) {
  const liste = [];
  for (const z of zumreler(uyelikId)) {
    for (const t of db.prepare('SELECT * FROM zumre_toplantilari WHERE branch_id = ? AND course_id = ?').all(z.sube, z.id)) {
      for (const tarih of aralikTarihleri(t, bas, bit)) liste.push({ baslik: t.baslik, zumre: z.ad, tarih, saat: t.saat, yer: t.yer, baskanlar: false });
    }
  }
  const uye = db.prepare('SELECT branch_id, zumre_baskani FROM memberships WHERE id = ?').get(uyelikId);
  if (uye?.zumre_baskani) {
    for (const t of db.prepare('SELECT t.* FROM baskan_toplantilari t WHERE t.id IN (SELECT toplanti_id FROM baskan_toplanti_okullari WHERE branch_id = ?) AND t.tarih >= ? AND t.tarih <= ?').all(uye.branch_id, bas, bit)) {
      liste.push({ baslik: t.baslik, zumre: 'Zümre başkanları', tarih: t.tarih, saat: t.saat, yer: t.yer, baskanlar: true });
    }
  }
  return liste;
}

// ---- Zümre başkanları toplantısı: yönetim kurar; yönetim ve katılan okulların başkanları görür ----
const YONETIM_ROLLERI = new Set(['kurum-yonetimi', 'mudur', 'mudur_yrd']);
const yonetimMi = o => o.role === 'yonetim' && kisiRolleri(o.user_id, o.gorev).some(r => YONETIM_ROLLERI.has(r.kod));
const kurumMu = o => o.gorev === 'kurum' || kisiRolleri(o.user_id, o.gorev).some(r => r.kod === 'kurum-yonetimi');

// Yöneticinin kendi okulları (üyelik okulu + müdür / müdür yardımcısı olduğu okullar)
function kendiOkullari(o) {
  const uyelik = db.prepare('SELECT branch_id FROM memberships WHERE id = ?').get(o.membership_id);
  return new Set([uyelik?.branch_id, ...db.prepare('SELECT branch_id FROM okul_yoneticileri WHERE user_id = ?').all(o.user_id).map(r => r.branch_id)].filter(Boolean));
}

// Toplantıya katabileceği okullar: kurum yönetimi hepsini; okul müdürü kendi okulunu ve aynı türdeki (örn. başka kampüslerdeki ilkokullar) okulları
function katilabilirOkullar(o) {
  const tum = db.prepare(`SELECT b.id, b.name AS ad, b.tur, k.name AS kampus FROM branches b LEFT JOIN kampusler k ON k.id = b.campus_id
    ORDER BY k.name, b.name`).all();
  if (kurumMu(o)) return tum;
  const kendi = kendiOkullari(o);
  const turler = new Set(tum.filter(b => kendi.has(b.id) && b.tur).map(b => b.tur));
  return tum.filter(b => kendi.has(b.id) || (b.tur && turler.has(b.tur)));
}

async function baskanlarApi({ req, res, url, o, json, govde, denetle }) {
  const yol = url.pathname;
  const hata = (kod, mesaj) => { json(res, kod, { hata: mesaj }); return true; };
  const yonetim = yonetimMi(o);
  const kurum = yonetim && kurumMu(o);
  const benimUye = o.role === 'ogretmen' ? db.prepare('SELECT branch_id, zumre_baskani FROM memberships WHERE id = ?').get(o.membership_id) : null;
  const baskan = !!benimUye?.zumre_baskani;
  if (!yonetim && !baskan) return hata(403, 'Bu toplantılar yalnızca yönetim ve zümre başkanlarına açıktır');
  const basladi = t => t.tarih < trTarih() || (t.tarih === trTarih() && t.saat <= trSaat());
  const kendi = yonetim ? kendiOkullari(o) : null;
  const okullariOf = id => db.prepare('SELECT b.id, b.name AS ad FROM baskan_toplanti_okullari x JOIN branches b ON b.id = x.branch_id WHERE x.toplanti_id = ? ORDER BY b.name').all(id);
  // Bu kişi toplantıyı görebilir mi? Kurum yönetimi hepsini; müdür kendi okulu katılıyorsa ya da kendisi kurduysa; başkan okulu katılıyorsa
  const gorebilir = (t, okullar) => yonetim
    ? kurum || t.olusturan_user_id === o.user_id || okullar.some(x => kendi.has(x.id))
    : okullar.some(x => x.id === benimUye.branch_id);
  const duzenleyebilir = t => kurum || (yonetim && t.olusturan_user_id === o.user_id);

  if (req.method === 'GET' && yol === '/api/zumre/baskanlar/liste') {
    const satirlar = db.prepare(`SELECT t.*, uo.full_name AS olusturan, uk.full_name AS kararYazan
      FROM baskan_toplantilari t JOIN users uo ON uo.id = t.olusturan_user_id
      LEFT JOIN users uk ON uk.id = t.karar_yazan_user_id ORDER BY t.tarih DESC, t.saat DESC, t.id DESC`).all();
    const toplantilar = [];
    for (const t of satirlar) {
      const okullar = okullariOf(t.id);
      if (!gorebilir(t, okullar)) continue;
      toplantilar.push({ id: t.id, okullar, okulIds: okullar.map(x => x.id), okul: okullar.map(x => x.ad).join(', '), baslik: t.baslik, tarih: t.tarih, saat: t.saat, yer: t.yer, gundem: t.gundem,
        karar: t.karar, kararYazan: t.kararYazan, kararZamani: t.karar_zamani, olusturan: t.olusturan, basladi: basladi(t), duzenleyebilir: duzenleyebilir(t) });
    }
    return json(res, 200, {
      yonetim, kurum,
      okullar: yonetim ? katilabilirOkullar(o) : [],
      varsayilan: yonetim && !kurum ? [...kendi] : [],
      toplantilar,
    }), true;
  }
  if (req.method !== 'POST') return false;
  const b = await govde(req);
  const toplanti = id => db.prepare('SELECT * FROM baskan_toplantilari WHERE id = ?').get(tamSayi(id) || 0);

  if (yol === '/api/zumre/baskanlar/kaydet') {
    if (!yonetim) return hata(403, 'Toplantıyı yalnızca yönetim kurar');
    const secilen = [...new Set((Array.isArray(b.okulIds) ? b.okulIds : [b.okulId]).map(x => tamSayi(x)).filter(Boolean))];
    if (!secilen.length) return hata(400, 'En az bir okul seçin');
    const tumu = new Set(db.prepare('SELECT id FROM branches').all().map(r => r.id));
    if (secilen.some(i => !tumu.has(i))) return hata(400, 'Okul bulunamadı');
    const izinli = new Set(katilabilirOkullar(o).map(x => x.id));
    if (secilen.some(i => !izinli.has(i))) return hata(403, 'Yalnızca kendi okul türünüzdeki okulları (örn. ilkokul müdürü yalnızca ilkokulları) toplantıya katabilirsiniz');
    const tarih = String(b.tarih || ''), saat = String(b.saat || '');
    if (!tarihGecerli(tarih)) return hata(400, 'Tarih geçersiz');
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(saat)) return hata(400, 'Saat geçersiz');
    const baslik = metin(b.baslik, 80) || 'Zümre başkanları toplantısı', yer = metin(b.yer, 60), gundem = metin(b.gundem, 500);
    const id = tamSayi(b.id);
    const yaz = tid => {
      db.prepare('DELETE FROM baskan_toplanti_okullari WHERE toplanti_id = ?').run(tid);
      for (const s of secilen) db.prepare('INSERT INTO baskan_toplanti_okullari (toplanti_id, branch_id) VALUES (?,?)').run(tid, s);
    };
    db.exec('BEGIN');
    try {
      if (id) {
        const t = toplanti(id);
        if (!t) { db.exec('ROLLBACK'); return hata(404, 'Toplantı bulunamadı'); }
        if (!duzenleyebilir(t)) { db.exec('ROLLBACK'); return hata(403, 'Bu toplantıyı yalnızca kuran yönetici ya da kurum yönetimi düzenler'); }
        db.prepare('UPDATE baskan_toplantilari SET branch_id = ?, baslik = ?, tarih = ?, saat = ?, yer = ?, gundem = ? WHERE id = ?').run(secilen[0], baslik, tarih, saat, yer, gundem, id);
        yaz(id);
        db.exec('COMMIT');
        denetle(o.user_id, 'baskan-toplanti-guncelle', { id, okullar: secilen });
        return json(res, 200, { tamam: true, id }), true;
      }
      const yeni = Number(db.prepare('INSERT INTO baskan_toplantilari (branch_id, baslik, tarih, saat, yer, gundem, olusturan_user_id, created_at) VALUES (?,?,?,?,?,?,?,?)')
        .run(secilen[0], baslik, tarih, saat, yer, gundem, o.user_id, Date.now()).lastInsertRowid);
      yaz(yeni);
      db.exec('COMMIT');
      denetle(o.user_id, 'baskan-toplanti-ekle', { id: yeni, okullar: secilen });
      return json(res, 200, { tamam: true, id: yeni }), true;
    } catch (e) { try { db.exec('ROLLBACK'); } catch {} throw e; }
  }

  if (yol === '/api/zumre/baskanlar/sil') {
    if (!yonetim) return hata(403, 'Toplantıyı yalnızca yönetim siler');
    const t = toplanti(b.id);
    if (!t) return hata(404, 'Toplantı bulunamadı');
    if (!duzenleyebilir(t)) return hata(403, 'Bu toplantıyı yalnızca kuran yönetici ya da kurum yönetimi siler');
    db.prepare('DELETE FROM baskan_toplanti_okullari WHERE toplanti_id = ?').run(t.id);
    db.prepare('DELETE FROM baskan_toplantilari WHERE id = ?').run(t.id);
    denetle(o.user_id, 'baskan-toplanti-sil', { id: t.id });
    return json(res, 200, { tamam: true }), true;
  }

  // Alınan kararlar: toplantıyı görebilen yönetici ya da katılan okulun zümre başkanı yazar; toplantı yapıldıktan sonra, boş metin kararı siler
  if (yol === '/api/zumre/baskanlar/karar') {
    const t = toplanti(b.id);
    if (!t) return hata(404, 'Toplantı bulunamadı');
    if (!gorebilir(t, okullariOf(t.id))) return hata(403, 'Bu toplantıya okulunuz katılmıyor');
    if (!basladi(t)) return hata(400, 'Toplantı henüz yapılmadı');
    const karar = metin(b.karar, 2000);
    db.prepare('UPDATE baskan_toplantilari SET karar = ?, karar_yazan_user_id = ?, karar_zamani = ? WHERE id = ?').run(karar, karar ? o.user_id : null, karar ? Date.now() : null, t.id);
    denetle(o.user_id, 'baskan-toplanti-karar', { id: t.id });
    return json(res, 200, { tamam: true }), true;
  }
  return false;
}

export async function zumremApi({ req, res, url, o, json, govde, denetle }) {
  const yol = url.pathname;
  if (!yol.startsWith('/api/zumre/')) return false;
  const hata = (kod, mesaj) => { json(res, kod, { hata: mesaj }); return true; };
  if (!o) return hata(401, 'Oturum yok');
  if (yol.startsWith('/api/zumre/baskanlar/')) return baskanlarApi({ req, res, url, o, json, govde, denetle });
  if (o.role !== 'ogretmen') return hata(403, 'Bu işlem için yetkiniz yok');
  const sube = db.prepare('SELECT branch_id FROM memberships WHERE id = ?').get(o.membership_id).branch_id;
  const benim = zumreler(o.membership_id);
  const zumreBul = id => benim.find(z => z.id === tamSayi(id));

  if (req.method === 'GET' && yol === '/api/zumre/hatirlatma') return json(res, 200, { toplantilar: zumreHatirlatmalari(o.membership_id) }), true;

  // ---- Zümre özeti: üyeler, toplantılar, yazılar ----
  if (req.method === 'GET' && yol === '/api/zumre/benim') {
    const baskan = baskanMi(o.membership_id);
    return json(res, 200, {
      baskan,
      zumreler: benim.map(z => ({ id: z.id, ad: z.ad, ogretmenSayisi: uyeler(sube, z.id, o.membership_id).length })),
    }), true;
  }

  if (req.method === 'GET' && yol === '/api/zumre/detay') {
    const z = zumreBul(url.searchParams.get('courseId'));
    if (!z) return hata(404, 'Zümre bulunamadı');
    const kisiler = uyeler(sube, z.id, o.membership_id);
    const ben = kisiler.find(k => k.ben);
    const baskan = !!ben?.baskan;
    const kayitlar = db.prepare(`SELECT k.*, u.full_name AS yazan FROM zumre_toplanti_kararlari k JOIN memberships m ON m.id = k.yazan_membership_id JOIN users u ON u.id = m.user_id
      WHERE k.branch_id = ? AND k.course_id = ? ORDER BY k.tarih DESC, k.saat DESC, k.id DESC LIMIT ?`).all(sube, z.id, KARAR_SINIRI);
    const kayitli = new Set(db.prepare("SELECT toplanti_id || '|' || tarih AS a FROM zumre_toplanti_kararlari WHERE branch_id = ? AND course_id = ?").all(sube, z.id).map(r => r.a));
    const toplantilar = db.prepare('SELECT * FROM zumre_toplantilari WHERE branch_id = ? AND course_id = ? ORDER BY baslangic, saat').all(sube, z.id)
      .map(t => {
        // Yapılmış ama kararı yazılmamış son toplantı: "Toplantıyı bitir" bunun için görünür
        const son = gerceklesenler(t).at(-1);
        return { id: t.id, baslik: t.baslik, tekrar: t.tekrar, baslangic: t.baslangic, saat: t.saat, yer: t.yer, gundem: t.gundem, siradaki: siradakiler(t, 3),
          bekleyen: son && !kayitli.has(t.id + '|' + son) ? son : null };
      })
      .sort((a, b) => (a.siradaki[0] || '9999').localeCompare(b.siradaki[0] || '9999'));
    const yazilar = db.prepare(`SELECT i.id, i.metin, i.created_at AS zaman, i.membership_id AS yazanId, u.full_name AS yazan, m.zumre_baskani AS baskan
      FROM zumre_iletileri i JOIN memberships m ON m.id = i.membership_id JOIN users u ON u.id = m.user_id
      WHERE i.branch_id = ? AND i.course_id = ? ORDER BY i.created_at DESC, i.id DESC LIMIT ?`).all(sube, z.id, ILETI_SINIRI)
      .map(r => ({ id: r.id, metin: r.metin, zaman: r.zaman, yazan: r.yazan, baskan: !!r.baskan, benim: r.yazanId === o.membership_id }));
    const kararlar = kayitlar.map(k => ({ id: k.id, toplantiId: k.toplanti_id, baslik: k.baslik, tarih: k.tarih, saat: k.saat, yer: k.yer, karar: k.karar, yazan: k.yazan, zaman: k.guncellendi || k.created_at }));
    return json(res, 200, { zumre: { id: z.id, ad: z.ad }, baskan, ogretmenler: kisiler, toplantilar, kararlar, yazilar, tekrarlar: TEKRAR }), true;
  }

  if (req.method !== 'POST') return false;
  const b = await govde(req);

  // ---- Toplantı kur / güncelle / sil (yalnızca zümre başkanı) ----
  if (yol === '/api/zumre/toplanti') {
    const z = zumreBul(b.courseId);
    if (!z) return hata(404, 'Zümre bulunamadı');
    if (!baskanMi(o.membership_id)) return hata(403, 'Toplantıyı yalnızca zümre başkanı kurar');
    const baslik = metin(b.baslik, 80) || 'Zümre toplantısı';
    const tekrar = TEKRAR[b.tekrar] ? b.tekrar : null;
    const tarih = String(b.tarih || ''), saat = String(b.saat || '');
    if (!tekrar) return hata(400, 'Tekrar türü geçersiz');
    if (!tarihGecerli(tarih)) return hata(400, 'Tarih geçersiz');
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(saat)) return hata(400, 'Saat geçersiz');
    const yer = metin(b.yer, 60), gundem = metin(b.gundem, 500);
    // Rutin toplantı hiçbir okul gününe denk gelmiyorsa (ör. hafta sonu) hatırlatma hiç çıkmaz
    if (tekrar !== 'yok' && !siradakiler({ tekrar, baslangic: tarih, saat: '00:00' }, 1).length) return hata(400, 'Rutin toplantı için okul günü seçin');
    const id = tamSayi(b.id);
    if (id) {
      const var_ = db.prepare('SELECT 1 FROM zumre_toplantilari WHERE id = ? AND branch_id = ? AND course_id = ?').get(id, sube, z.id);
      if (!var_) return hata(404, 'Toplantı bulunamadı');
      db.prepare('UPDATE zumre_toplantilari SET baslik = ?, tekrar = ?, baslangic = ?, saat = ?, yer = ?, gundem = ? WHERE id = ?').run(baslik, tekrar, tarih, saat, yer, gundem, id);
      denetle(o.user_id, 'zumre-toplanti-guncelle', { id });
      return json(res, 200, { tamam: true, id }), true;
    }
    const yeni = Number(db.prepare('INSERT INTO zumre_toplantilari (branch_id, course_id, baslik, tekrar, baslangic, saat, yer, gundem, olusturan_membership_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)')
      .run(sube, z.id, baslik, tekrar, tarih, saat, yer, gundem, o.membership_id, Date.now()).lastInsertRowid);
    denetle(o.user_id, 'zumre-toplanti-ekle', { id: yeni, courseId: z.id });
    return json(res, 200, { tamam: true, id: yeni }), true;
  }

  if (yol === '/api/zumre/toplanti-sil') {
    const z = zumreBul(b.courseId);
    if (!z) return hata(404, 'Zümre bulunamadı');
    if (!baskanMi(o.membership_id)) return hata(403, 'Toplantıyı yalnızca zümre başkanı siler');
    const s = db.prepare('DELETE FROM zumre_toplantilari WHERE id = ? AND branch_id = ? AND course_id = ?').run(tamSayi(b.id) || 0, sube, z.id);
    if (!s.changes) return hata(404, 'Toplantı bulunamadı');
    denetle(o.user_id, 'zumre-toplanti-sil', { id: b.id });
    return json(res, 200, { tamam: true }), true;
  }

  // ---- Toplantı kararı: "toplantıyı bitir" (yalnızca zümre başkanı); aynı toplantı gününe tekrar yazılırsa güncellenir ----
  if (yol === '/api/zumre/karar') {
    const z = zumreBul(b.courseId);
    if (!z) return hata(404, 'Zümre bulunamadı');
    if (!baskanMi(o.membership_id)) return hata(403, 'Kararı yalnızca zümre başkanı yazar');
    const t = db.prepare('SELECT * FROM zumre_toplantilari WHERE id = ? AND branch_id = ? AND course_id = ?').get(tamSayi(b.toplantiId) || 0, sube, z.id);
    if (!t) return hata(404, 'Toplantı bulunamadı');
    const tarih = String(b.tarih || '');
    if (!gerceklesenler(t).includes(tarih)) return hata(400, 'Bu toplantı henüz yapılmadı');
    const karar = metin(b.karar, 2000);
    if (!karar) return hata(400, 'Karar notu boş olamaz');
    const var_ = db.prepare('SELECT id FROM zumre_toplanti_kararlari WHERE toplanti_id = ? AND tarih = ?').get(t.id, tarih);
    if (var_) db.prepare('UPDATE zumre_toplanti_kararlari SET karar = ?, yazan_membership_id = ?, guncellendi = ? WHERE id = ?').run(karar, o.membership_id, Date.now(), var_.id);
    else db.prepare('INSERT INTO zumre_toplanti_kararlari (branch_id, course_id, toplanti_id, baslik, tarih, saat, yer, karar, yazan_membership_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)')
      .run(sube, z.id, t.id, t.baslik, tarih, t.saat, t.yer, karar, o.membership_id, Date.now());
    denetle(o.user_id, 'zumre-toplanti-karar', { toplantiId: t.id, tarih });
    return json(res, 200, { tamam: true }), true;
  }

  if (yol === '/api/zumre/karar-sil') {
    const z = zumreBul(b.courseId);
    if (!z) return hata(404, 'Zümre bulunamadı');
    if (!baskanMi(o.membership_id)) return hata(403, 'Kararı yalnızca zümre başkanı siler');
    const s = db.prepare('DELETE FROM zumre_toplanti_kararlari WHERE id = ? AND branch_id = ? AND course_id = ?').run(tamSayi(b.id) || 0, sube, z.id);
    if (!s.changes) return hata(404, 'Karar bulunamadı');
    denetle(o.user_id, 'zumre-karar-sil', { id: b.id });
    return json(res, 200, { tamam: true }), true;
  }

  // ---- Yazılar: zümrenin tüm öğretmenleri yazabilir; kendi yazısını sahibi, herhangi birini başkan siler ----
  if (yol === '/api/zumre/yazi') {
    const z = zumreBul(b.courseId);
    if (!z) return hata(404, 'Zümre bulunamadı');
    const m = metin(b.metin, 1000);
    if (!m) return hata(400, 'Yazı boş olamaz');
    db.prepare('INSERT INTO zumre_iletileri (branch_id, course_id, membership_id, metin, created_at) VALUES (?,?,?,?,?)').run(sube, z.id, o.membership_id, m, Date.now());
    return json(res, 200, { tamam: true }), true;
  }

  if (yol === '/api/zumre/yazi-sil') {
    const z = zumreBul(b.courseId);
    if (!z) return hata(404, 'Zümre bulunamadı');
    const y = db.prepare('SELECT id, membership_id FROM zumre_iletileri WHERE id = ? AND branch_id = ? AND course_id = ?').get(tamSayi(b.id) || 0, sube, z.id);
    if (!y) return hata(404, 'Yazı bulunamadı');
    if (y.membership_id !== o.membership_id && !baskanMi(o.membership_id)) return hata(403, 'Yalnızca kendi yazınızı silebilirsiniz');
    db.prepare('DELETE FROM zumre_iletileri WHERE id = ?').run(y.id);
    return json(res, 200, { tamam: true }), true;
  }

  return false;
}
