import { db, tcGecerliMi, FOTO_SQL } from './db.js';
import { GOREVLER } from './kurum.js';
import { YAKINLIK } from './ogrenci.js';
import { bransVarsayilanlari, zumreRolunuEsitle, zumreBaskaniAyarla } from './zumrem.js';
import { KULUP_DERSI } from './ders-programi.js';

// Kişiler (personel): bir kişi tek hesaptır; yönetim ve öğretmen onun üyelikleridir.
// Ekleme, kimlik/telefon düzeltme, görev ve ayrılma işlemleri buradan yürür (yalnızca kurum yönetimi; sunucu kapısı yolu denetler).
const tamSayi = (v, min, max) => {
  const n = Number(v);
  return Number.isInteger(n) && n >= min && n <= max ? n : null;
};
const telNormalize = t => String(t || '').replace(/\D/g, '').slice(-10);
const bos = v => v === null || v === undefined || v === '';
const maske = (s, bas, son) => s ? s.slice(0, bas) + '•'.repeat(Math.max(s.length - bas - son, 0)) + s.slice(-son) : '';
const PERSONEL = "('yonetim','ogretmen')";
const YOL = /^\/api\/yonetim\/kullanici-(detay|secenek|kontrol|kimlik|yeni|mudur|veli|dersler|brans|zumre|ayril|geri|sil)$/;

class KullaniciHatasi extends Error {}
function islem(fn) {
  db.exec('BEGIN');
  try { const s = fn(); db.exec('COMMIT'); return s; } catch (e) { db.exec('ROLLBACK'); throw e; }
}

// Kimlik biçimi: 11 haneli T.C. ya da pasaport; hata varsa metin döner
function kimlikCoz(ham) {
  const kimlik = String(ham || '').trim().toUpperCase();
  const tcMi = /^\d{11}$/.test(kimlik);
  if (tcMi ? !tcGecerliMi(kimlik) : !/^[A-Z0-9]{5,20}$/.test(kimlik)) return { hata: 'Kimlik / pasaport numarası geçersiz' };
  return { kimlik, tcMi };
}
const adCoz = ham => {
  const ad = String(ham ?? '').replace(/\s+/g, ' ').trim();
  return ad.length < 3 || ad.length > 80 || !ad.includes(' ') ? null : ad;
};

// Yönetim üyeliği: yoksa açılır, pasifse yeniden etkinleştirilir. Kurum yönetimi üyeliğine dokunulmaz.
function yonetimUyeligi(userId, subeId) {
  const m = db.prepare("SELECT id, status FROM memberships WHERE user_id = ? AND branch_id = ? AND role = 'yonetim'").get(userId, subeId);
  if (!m) db.prepare("INSERT INTO memberships (user_id, branch_id, role, gorev) VALUES (?,?,'yonetim','okul')").run(userId, subeId);
  else if (m.status !== 'aktif') db.prepare("UPDATE memberships SET status = 'aktif' WHERE id = ?").run(m.id);
}
function ogretmenUyeligi(userId, subeId) {
  const m = db.prepare("SELECT id, status FROM memberships WHERE user_id = ? AND branch_id = ? AND role = 'ogretmen'").get(userId, subeId);
  if (m) { if (m.status !== 'aktif') db.prepare("UPDATE memberships SET status = 'aktif' WHERE id = ?").run(m.id); return m.id; }
  return Number(db.prepare("INSERT INTO memberships (user_id, branch_id, role, gorev) VALUES (?,?,'ogretmen','okul')").run(userId, subeId).lastInsertRowid);
}

// Müdür / müdür yardımcısı görevini verir; okulun müdürü zaten varsa KullaniciHatasi fırlatır
function mudurGorevi(userId, subeId, gorev) {
  if (!GOREVLER[gorev]) throw new KullaniciHatasi('Görev seçin (müdür ya da müdür yardımcısı)');
  if (gorev === 'mudur') {
    const var_ = db.prepare("SELECT u.full_name AS ad, y.user_id FROM okul_yoneticileri y JOIN users u ON u.id = y.user_id WHERE y.branch_id = ? AND y.gorev = 'mudur'").get(subeId);
    if (var_ && var_.user_id !== userId) throw new KullaniciHatasi(`Okulun müdürü zaten var (${var_.ad}); önce onun görevini kaldırın`);
  }
  db.prepare('DELETE FROM okul_yoneticileri WHERE branch_id = ? AND user_id = ?').run(subeId, userId);
  db.prepare('INSERT INTO okul_yoneticileri (branch_id, user_id, gorev, created_at) VALUES (?,?,?,?)').run(subeId, userId, gorev, Date.now());
  yonetimUyeligi(userId, subeId);
}

function dersleriYaz(uyelikId, dersIds) {
  db.prepare('DELETE FROM teacher_courses WHERE teacher_membership_id = ?').run(uyelikId);
  const ekle = db.prepare('INSERT INTO teacher_courses (teacher_membership_id, course_id) VALUES (?,?)');
  for (const d of dersIds) ekle.run(uyelikId, d);
  bransVarsayilanlari();
}
const gecerliDersler = v => {
  const ids = Array.isArray(v) ? [...new Set(v.map(Number))] : [];
  return ids.every(d => Number.isInteger(d) && db.prepare('SELECT 1 FROM courses WHERE id = ?').get(d)) ? ids : null;
};

function detay(id, aktorId) {
  const u = db.prepare(`SELECT u.id, u.tc_no, u.passport_no, u.phone, u.full_name, u.created_at, ${FOTO_SQL} AS foto FROM users u WHERE u.id = ?`).get(id);
  if (!u) return null;
  const uyelikler = db.prepare(`SELECT m.id, m.role, m.status, m.gorev, m.branch_id, m.brans_id, m.zumre_baskani, b.name AS sube FROM memberships m
    LEFT JOIN branches b ON b.id = m.branch_id WHERE m.user_id = ? ORDER BY m.role, b.name`).all(id);
  const personelUyeleri = uyelikler.filter(m => m.role === 'yonetim' || m.role === 'ogretmen');
  const ogretmenIds = uyelikler.filter(m => m.role === 'ogretmen').map(m => m.id);
  const kosul = ogretmenIds.length ? ogretmenIds.join(',') : '0';
  return {
    id: u.id, ad: u.full_name, foto: u.foto, kendisi: u.id === aktorId,
    kimlikTuru: u.tc_no ? 'T.C.' : 'Pasaport', kimlik: maske(u.tc_no || u.passport_no, 3, 2), telefon: maske(u.phone, 3, 2),
    kayit: u.created_at,
    uyelikler: personelUyeleri.map(m => ({ id: m.id, rol: m.role, durum: m.status, gorev: m.gorev, subeId: m.branch_id, sube: m.sube, bransId: m.brans_id, baskan: !!m.zumre_baskani })),
    diger: uyelikler.filter(m => m.role === 'ogrenci' || m.role === 'veli').map(m => ({ id: m.id, rol: m.role, durum: m.status, sube: m.sube })),
    veliOgrenciler: db.prepare(`SELECT sm.id, su.full_name AS ad, b.name AS sube, c.name AS sinif, COALESCE(ab.yakinlik, '') AS yakinlik, pm.branch_id AS subeId
      FROM memberships pm JOIN guardians g ON g.parent_membership_id = pm.id JOIN memberships sm ON sm.id = g.student_membership_id
      JOIN users su ON su.id = sm.user_id LEFT JOIN branches b ON b.id = sm.branch_id
      LEFT JOIN class_students cs ON cs.student_membership_id = sm.id LEFT JOIN classes c ON c.id = cs.class_id
      LEFT JOIN aile_bilgi ab ON ab.student_membership_id = sm.id AND ab.parent_membership_id = pm.id
      WHERE pm.user_id = ? AND pm.role = 'veli' AND pm.status = 'aktif' ORDER BY su.full_name`).all(id),
    roller: db.prepare('SELECT rol_id FROM kullanici_roller WHERE user_id = ?').all(id).map(r => r.rol_id),
    okulGorevleri: db.prepare('SELECT y.id, y.gorev, y.branch_id AS okulId, b.name AS okul FROM okul_yoneticileri y JOIN branches b ON b.id = y.branch_id WHERE y.user_id = ?').all(id),
    dersler: db.prepare(`SELECT teacher_membership_id AS uyelikId, course_id AS dersId FROM teacher_courses WHERE teacher_membership_id IN (${kosul})`).all(),
    atamalar: db.prepare(`SELECT a.teacher_membership_id AS uyelikId, c.name AS sinif, co.name AS ders, a.weekly_hours AS saat
      FROM assignments a JOIN classes c ON c.id = a.class_id JOIN courses co ON co.id = a.course_id
      WHERE a.teacher_membership_id IN (${kosul}) ORDER BY c.name, co.name`).all(),
    sinifOgretmenligi: db.prepare(`SELECT id, name AS sinif FROM classes WHERE homeroom_membership_id IN (${kosul}) ORDER BY name`).all(),
  };
}

export async function kisiApi({ req, res, url, o, json, govde, denetle }) {
  const yol = url.pathname;
  if (!YOL.test(yol)) return false;
  const hata = (kod, mesaj) => { json(res, kod, { hata: mesaj }); return true; };
  const ok = (kod = 200, ek = {}) => { json(res, kod, { tamam: true, ...ek }); return true; };
  const ad = yol.slice('/api/yonetim/kullanici-'.length);

  if (req.method === 'GET') {
    if (ad === 'secenek') {
      json(res, 200, {
        okullar: db.prepare('SELECT id, name AS ad FROM branches ORDER BY id').all(),
        dersler: db.prepare("SELECT id, name AS ad FROM courses WHERE name != 'Kulüp' ORDER BY name").all(),
        roller: db.prepare("SELECT id, kod, ad, aciklama FROM roller WHERE kod IS NULL OR kod NOT IN ('kurum-yonetimi','mudur','mudur_yrd') ORDER BY sistem DESC, id").all(),
        gorevler: GOREVLER,
      });
      return true;
    }
    if (ad === 'detay') {
      const d = detay(tamSayi(url.searchParams.get('id'), 1, 1e9), o.user_id);
      return d ? (json(res, 200, d), true) : hata(404, 'Kişi bulunamadı');
    }
    if (ad === 'kontrol') {
      // Sihirbaz: aynı kimlikle kayıtlı kişi var mı? (yalnızca ad ve mevcut görevleri döner)
      const k = kimlikCoz(url.searchParams.get('kimlik'));
      if (k.hata) return hata(400, k.hata);
      const u = db.prepare('SELECT id, full_name FROM users WHERE tc_no = gz(?) OR passport_no = gz(?)').get(k.kimlik, k.kimlik);
      if (!u) { json(res, 200, { var: false }); return true; }
      const uyeler = db.prepare(`SELECT m.role, m.status, b.name AS sube FROM memberships m LEFT JOIN branches b ON b.id = m.branch_id WHERE m.user_id = ?`).all(u.id);
      json(res, 200, { var: true, id: u.id, ad: u.full_name, uyelikler: uyeler });
      return true;
    }
    return false;
  }
  if (req.method !== 'POST') return false;
  const b = await govde(req);
  const kisi = tamSayi(b.userId, 1, 1e9) && db.prepare('SELECT id, full_name, phone FROM users WHERE id = ?').get(Number(b.userId));
  const subeVar = id => !!tamSayi(id, 1, 1e9) && !!db.prepare('SELECT 1 FROM branches WHERE id = ?').get(Number(id));

  // Yeni personel: tek akışta hesap + görev + dersler. Kimlik kayıtlıysa telefon eşleşmeli; yeni üyelik mevcut hesaba eklenir.
  if (ad === 'yeni') {
    const adi = adCoz(b.ad);
    const k = kimlikCoz(b.kimlik);
    const tel = telNormalize(b.telefon);
    const subeId = Number(b.subeId);
    if (!adi) return hata(400, 'Ad ve soyadı birlikte yazın');
    if (k.hata) return hata(400, k.hata);
    if (!/^\d{10}$/.test(tel)) return hata(400, 'Telefon 10 haneli olmalı');
    if (!subeVar(subeId)) return hata(400, 'Okul seçin');
    if (!b.ogretmen && !b.yonetim) return hata(400, 'En az bir görev seçin (öğretmen ya da yönetim)');
    const dersIds = b.ogretmen ? gecerliDersler(b.dersIds ?? []) : [];
    if (!dersIds) return hata(400, 'Geçersiz ders seçimi');
    const rol = b.yonetim && !bos(b.rolId) ? db.prepare("SELECT id, kod FROM roller WHERE id = ?").get(Number(b.rolId)) : null;
    if (b.yonetim && !bos(b.rolId) && (!rol || ['kurum-yonetimi', 'mudur', 'mudur_yrd', 'zumre'].includes(rol.kod))) return hata(400, 'Geçersiz rol');
    const mudur = b.yonetim && b.mudurGorev ? String(b.mudurGorev) : '';

    let mevcut = false;
    let hataMetni = null;
    let userId;
    try { userId = islem(() => {
      const var_ = db.prepare('SELECT id, phone FROM users WHERE tc_no = gz(?) OR passport_no = gz(?)').get(k.kimlik, k.kimlik);
      if (var_ && var_.phone !== tel) { hataMetni = 'Bu kimlik numarası başka bir telefonla kayıtlı'; return null; }
      mevcut = !!var_;
      const id = var_?.id ?? Number(db.prepare('INSERT INTO users (tc_no, passport_no, phone, full_name, created_at) VALUES (?,?,?,?,?)')
        .run(k.tcMi ? k.kimlik : null, k.tcMi ? null : k.kimlik, tel, adi, Date.now()).lastInsertRowid);
      if (b.ogretmen) { const uid = ogretmenUyeligi(id, subeId); if (dersIds.length) dersleriYaz(uid, dersIds); }
      if (b.yonetim) {
        yonetimUyeligi(id, subeId);
        if (rol) db.prepare('INSERT OR IGNORE INTO kullanici_roller (user_id, rol_id) VALUES (?,?)').run(id, rol.id);
        if (mudur) mudurGorevi(id, subeId, mudur);
      }
      return id;
    }); } catch (e) { if (e instanceof KullaniciHatasi) return hata(409, e.message); throw e; }
    if (hataMetni && !userId) return hata(409, hataMetni);
    denetle(o.user_id, 'kullanici-yeni', { userId, subeId, ogretmen: !!b.ogretmen, yonetim: !!b.yonetim, mevcutHesap: mevcut });
    return ok(201, { id: userId, mevcut });
  }

  if (!kisi) return hata(404, 'Kişi bulunamadı');

  // Kimlik, telefon ve ad düzeltme: boş bırakılan kimlik/telefon değişmez
  if (ad === 'kimlik') {
    const adi = adCoz(b.ad);
    if (!adi) return hata(400, 'Ad ve soyadı birlikte yazın');
    const kimlikGirildi = !bos(b.kimlik) && String(b.kimlik).trim() !== '';
    const telGirildi = !bos(b.telefon) && String(b.telefon).trim() !== '';
    const tel = telGirildi ? telNormalize(b.telefon) : null;
    if (telGirildi && !/^\d{10}$/.test(tel)) return hata(400, 'Telefon 10 haneli olmalı');
    let k = null;
    if (kimlikGirildi) {
      k = kimlikCoz(b.kimlik);
      if (k.hata) return hata(400, k.hata);
      const baska = db.prepare('SELECT id, full_name FROM users WHERE (tc_no = gz(?) OR passport_no = gz(?)) AND id != ?').get(k.kimlik, k.kimlik, kisi.id);
      if (baska) return hata(409, `Bu kimlik numarası başka bir kişide kayıtlı (${baska.full_name})`);
    }
    islem(() => {
      db.prepare('UPDATE users SET full_name = ? WHERE id = ?').run(adi, kisi.id);
      if (k) db.prepare('UPDATE users SET tc_no = ?, passport_no = ? WHERE id = ?').run(k.tcMi ? k.kimlik : null, k.tcMi ? null : k.kimlik, kisi.id);
      if (telGirildi) db.prepare('UPDATE users SET phone = ? WHERE id = ?').run(tel, kisi.id);
    });
    denetle(o.user_id, 'kullanici-kimlik', { userId: kisi.id, ad: adi !== kisi.full_name, kimlik: !!k, telefon: telGirildi && tel !== kisi.phone });
    return ok();
  }

  // Veli bağlantısı: kişiyi bir öğrencinin velisi yap ya da bağlantıyı kaldır (veri öğrenci tarafında da aynı tablolarda durur)
  if (ad === 'veli') {
    const ogr = db.prepare("SELECT id, branch_id FROM memberships WHERE id = ? AND role = 'ogrenci'").get(tamSayi(b.ogrenciId, 1, 1e9) ?? 0);
    if (!ogr) return hata(404, 'Öğrenci bulunamadı');
    let veli = db.prepare("SELECT id, status FROM memberships WHERE user_id = ? AND branch_id = ? AND role = 'veli'").get(kisi.id, ogr.branch_id);
    if (b.ver === false) {
      if (!veli) return ok();
      islem(() => {
        db.prepare('DELETE FROM guardians WHERE parent_membership_id = ? AND student_membership_id = ?').run(veli.id, ogr.id);
        db.prepare('DELETE FROM aile_bilgi WHERE parent_membership_id = ? AND student_membership_id = ?').run(veli.id, ogr.id);
        if (!db.prepare('SELECT 1 FROM guardians WHERE parent_membership_id = ?').get(veli.id)) {
          db.prepare("UPDATE memberships SET status = 'pasif' WHERE id = ?").run(veli.id);
          db.prepare('DELETE FROM sessions WHERE membership_id = ?').run(veli.id);
        }
      });
      denetle(o.user_id, 'veli-coz', { veliId: veli.id, ogrId: ogr.id });
      return ok();
    }
    const yakinlik = String(b.yakinlik ?? '').trim();
    if (!YAKINLIK.includes(yakinlik)) return hata(400, 'Yakınlık seçin');
    if (db.prepare('SELECT COUNT(*) AS n FROM guardians WHERE student_membership_id = ?').get(ogr.id).n >= 6) return hata(409, 'Bir öğrenciye en çok 6 veli / yakın bağlanabilir');
    islem(() => {
      if (!veli) veli = { id: Number(db.prepare("INSERT INTO memberships (user_id, branch_id, role) VALUES (?,?, 'veli')").run(kisi.id, ogr.branch_id).lastInsertRowid) };
      else if (veli.status !== 'aktif') db.prepare("UPDATE memberships SET status = 'aktif' WHERE id = ?").run(veli.id);
      db.prepare('INSERT OR IGNORE INTO guardians (parent_membership_id, student_membership_id) VALUES (?,?)').run(veli.id, ogr.id);
      db.prepare('INSERT OR REPLACE INTO aile_bilgi (student_membership_id, parent_membership_id, yakinlik, meslek) VALUES (?,?,?,?)').run(ogr.id, veli.id, yakinlik, '');
    });
    denetle(o.user_id, 'veli-bagla', { veliId: veli.id, ogrId: ogr.id, mevcutHesap: true });
    return ok(201);
  }

  // Müdür / müdür yardımcısı görevi ver ya da kaldır (okul bazında)
  if (ad === 'mudur') {
    const subeId = Number(b.okulId);
    if (!subeVar(subeId)) return hata(404, 'Okul bulunamadı');
    if (!bos(b.gorev) && b.gorev !== '') {
      try { islem(() => mudurGorevi(kisi.id, subeId, b.gorev)); } catch (e) { if (e instanceof KullaniciHatasi) return hata(409, e.message); throw e; }
      denetle(o.user_id, 'okul-yonetici-ekle', { okulId: subeId, userId: kisi.id, gorev: b.gorev });
      return ok();
    }
    islem(() => {
      db.prepare('DELETE FROM okul_yoneticileri WHERE branch_id = ? AND user_id = ?').run(subeId, kisi.id);
      // Başka okul görevi ve ek rolü kalmadıysa okul kapsamlı yönetim girişi kapanır
      if (!db.prepare('SELECT 1 FROM okul_yoneticileri WHERE user_id = ?').get(kisi.id) && !db.prepare('SELECT 1 FROM kullanici_roller WHERE user_id = ?').get(kisi.id)) {
        db.prepare("UPDATE memberships SET status = 'pasif' WHERE user_id = ? AND role = 'yonetim' AND gorev = 'okul'").run(kisi.id);
      }
    });
    denetle(o.user_id, 'okul-yonetici-kaldir', { okulId: subeId, userId: kisi.id });
    return ok();
  }

  // Öğretmenin verebildiği dersler (üyelik bazında); sınıflarda kullanılan ders çıkarılamaz
  if (ad === 'dersler') {
    const m = db.prepare("SELECT id FROM memberships WHERE id = ? AND user_id = ? AND role = 'ogretmen'").get(tamSayi(b.uyelikId, 1, 1e9) ?? 0, kisi.id);
    if (!m) return hata(404, 'Öğretmenlik üyeliği bulunamadı');
    const dersIds = gecerliDersler(b.dersIds);
    if (!dersIds) return hata(400, 'Geçersiz ders seçimi');
    const brans = db.prepare('SELECT brans_id FROM memberships WHERE id = ?').get(m.id).brans_id;
    if (brans && !dersIds.includes(brans)) return hata(409, 'Branş dersi çıkarılamaz; önce branşı değiştirin');
    const kullanilan = db.prepare(`SELECT a.course_id AS dersId, co.name AS ders, c.name AS sinif FROM assignments a
      JOIN courses co ON co.id = a.course_id JOIN classes c ON c.id = a.class_id WHERE a.teacher_membership_id = ?`).all(m.id)
      .filter(x => !dersIds.includes(x.dersId));
    if (kullanilan.length) return hata(409, 'Önce sınıflardaki atamayı kaldırın: ' + kullanilan.map(x => `${x.sinif} ${x.ders}`).join(', '));
    islem(() => dersleriYaz(m.id, dersIds));
    denetle(o.user_id, 'ogretmen-dersleri', { uyelikId: m.id, dersIds });
    return ok();
  }

  // Öğretmenin tek branşı (zümresi buna göre kurulur); branş dersi, verdiği derslere de eklenir
  if (ad === 'brans') {
    const m = db.prepare("SELECT id, brans_id FROM memberships WHERE id = ? AND user_id = ? AND role = 'ogretmen'").get(tamSayi(b.uyelikId, 1, 1e9) ?? 0, kisi.id);
    if (!m) return hata(404, 'Öğretmenlik üyeliği bulunamadı');
    const dersId = tamSayi(b.bransId, 1, 1e9);
    const ders = dersId && db.prepare('SELECT id, name FROM courses WHERE id = ?').get(dersId);
    if (!ders) return hata(400, 'Branş seçin');
    if (ders.name === KULUP_DERSI) return hata(400, 'Kulüp bir branş olamaz');
    if (ders.id === m.brans_id) return ok();
    islem(() => {
      db.prepare('UPDATE memberships SET brans_id = ?, zumre_baskani = 0 WHERE id = ?').run(ders.id, m.id);
      db.prepare('INSERT OR IGNORE INTO teacher_courses (teacher_membership_id, course_id) VALUES (?,?)').run(m.id, ders.id);
      zumreRolunuEsitle();
    });
    denetle(o.user_id, 'ogretmen-brans', { uyelikId: m.id, bransId: ders.id });
    return ok();
  }

  // Zümre başkanlığı: okul + branş başına tek kişi, önceki başkandan devralınır
  if (ad === 'zumre') {
    const m = db.prepare("SELECT id FROM memberships WHERE id = ? AND user_id = ? AND role = 'ogretmen'").get(tamSayi(b.uyelikId, 1, 1e9) ?? 0, kisi.id);
    if (!m) return hata(404, 'Öğretmenlik üyeliği bulunamadı');
    let sonuc = null;
    islem(() => { sonuc = zumreBaskaniAyarla(m.id, !!b.baskan); });
    if (sonuc) return hata(409, sonuc);
    denetle(o.user_id, 'zumre-baskani', { uyelikId: m.id, baskan: !!b.baskan });
    return ok();
  }

  // Okuldan ayrıldı: personel üyelikleri pasifleşir, görev ve atamalar boşa alınır; geçmiş kayıtlar korunur
  if (ad === 'ayril' || ad === 'geri') {
    const subeFiltre = bos(b.subeId) ? null : Number(b.subeId);
    if (subeFiltre !== null && !subeVar(subeFiltre)) return hata(400, 'Okul bulunamadı');
    const hedef = db.prepare(`SELECT id, role, gorev, status, branch_id FROM memberships WHERE user_id = ? AND role IN ${PERSONEL}
      ${subeFiltre !== null ? 'AND branch_id = ' + subeFiltre : ''}`).all(kisi.id);
    if (!hedef.length) return hata(404, 'Personel görevi bulunamadı');
    if (ad === 'geri') {
      islem(() => { for (const m of hedef) db.prepare("UPDATE memberships SET status = 'aktif' WHERE id = ?").run(m.id); });
      denetle(o.user_id, 'kullanici-geri', { userId: kisi.id, subeId: subeFiltre });
      return ok();
    }
    if (kisi.id === o.user_id) return hata(400, 'Kendi hesabınızı kapatamazsınız');
    const kurumUye = hedef.find(m => m.role === 'yonetim' && m.gorev === 'kurum' && m.status === 'aktif');
    if (kurumUye) {
      const kalan = db.prepare("SELECT COUNT(*) AS n FROM memberships WHERE role = 'yonetim' AND gorev = 'kurum' AND status = 'aktif' AND user_id != ?").get(kisi.id).n;
      if (kalan === 0) return hata(409, 'Son aktif kurum yönetimi kapatılamaz');
    }
    const ozet = { boslananDers: 0, sinifOgretmenligi: 0 };
    islem(() => {
      const ogretmenler = hedef.filter(m => m.role === 'ogretmen').map(m => m.id);
      for (const m of hedef) {
        db.prepare("UPDATE memberships SET status = 'pasif', zumre_baskani = 0 WHERE id = ?").run(m.id);
        db.prepare('DELETE FROM sessions WHERE membership_id = ?').run(m.id);
      }
      for (const id of ogretmenler) {
        ozet.boslananDers += Number(db.prepare('UPDATE assignments SET teacher_membership_id = NULL WHERE teacher_membership_id = ?').run(id).changes);
        ozet.sinifOgretmenligi += Number(db.prepare('UPDATE classes SET homeroom_membership_id = NULL WHERE homeroom_membership_id = ?').run(id).changes);
      }
      zumreRolunuEsitle();
      const subeler = [...new Set(hedef.map(m => m.branch_id))];
      for (const s of subeler) db.prepare('DELETE FROM okul_yoneticileri WHERE branch_id = ? AND user_id = ?').run(s, kisi.id);
    });
    denetle(o.user_id, 'kullanici-ayril', { userId: kisi.id, subeId: subeFiltre, ...ozet });
    return ok(200, ozet);
  }

  // Hiç hareketi olmayan yanlış kayıt: bağlı kaydı olanlar silinemez (yabancı anahtar engeller), "ayrıldı" işaretlenir
  if (ad === 'sil') {
    if (kisi.id === o.user_id) return hata(400, 'Kendi hesabınızı silemezsiniz');
    if (db.prepare("SELECT 1 FROM memberships WHERE user_id = ? AND (role NOT IN ('yonetim','ogretmen') OR gorev = 'kurum')").get(kisi.id)) {
      return hata(409, 'Bu kişinin öğrenci, veli ya da kurum yönetimi kaydı var; silinemez');
    }
    try {
      islem(() => {
        const uyeler = db.prepare('SELECT id FROM memberships WHERE user_id = ?').all(kisi.id).map(m => m.id);
        for (const id of uyeler) {
          db.prepare('DELETE FROM sessions WHERE membership_id = ?').run(id);
          db.prepare('DELETE FROM teacher_courses WHERE teacher_membership_id = ?').run(id);
          db.prepare('DELETE FROM memberships WHERE id = ?').run(id);
        }
        db.prepare('DELETE FROM okul_yoneticileri WHERE user_id = ?').run(kisi.id);
        db.prepare('DELETE FROM kullanici_roller WHERE user_id = ?').run(kisi.id);
        db.prepare('DELETE FROM kullanici_foto WHERE user_id = ?').run(kisi.id);
        db.prepare('DELETE FROM profil_bilgi WHERE user_id = ?').run(kisi.id);
        db.prepare('DELETE FROM otps WHERE user_id = ?').run(kisi.id);
        db.prepare('DELETE FROM users WHERE id = ?').run(kisi.id);
      });
    } catch {
      return hata(409, 'Kişinin geçmiş kayıtları var (ders, devamsızlık vb.); silmek yerine "Okuldan ayrıldı" olarak işaretleyin');
    }
    denetle(o.user_id, 'kullanici-sil', { userId: kisi.id });
    return ok();
  }
  return false;
}
