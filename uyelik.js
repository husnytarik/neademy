import { db } from './db.js';
import { zumreRolunuEsitle } from './zumrem.js';

// Personel üyelikleri için ortak işlemler: anlık görüntü (geri alma), okul bazlı müdür görevi kaldırma ve denetim geçmişi.
// Rol küresel kalır (kullanici_roller); hangi okulda geçerli olduğu kişinin yönetim üyeliğiyle belirlenir.

export class KullaniciHatasi extends Error {}

export function islem(fn) {
  db.exec('BEGIN');
  try { const s = fn(); db.exec('COMMIT'); return s; } catch (e) { db.exec('ROLLBACK'); throw e; }
}

const PERSONEL = "('yonetim','ogretmen')";

// Kişinin personel durumunun bir anlık görüntüsü. Kimlik, telefon gibi kişisel alanlar içermez.
export function anlik(userId) {
  const ogretmenler = `SELECT id FROM memberships WHERE user_id = ${Number(userId)} AND role = 'ogretmen'`;
  return {
    uyelikler: db.prepare(`SELECT id, role AS rol, status AS durum, gorev, branch_id AS sube, brans_id AS brans, zumre_baskani AS baskan
      FROM memberships WHERE user_id = ? AND role IN ${PERSONEL} ORDER BY id`).all(userId).map(m => ({ ...m })),
    gorevler: db.prepare('SELECT branch_id AS sube, gorev FROM okul_yoneticileri WHERE user_id = ? ORDER BY branch_id').all(userId).map(g => ({ ...g })),
    roller: db.prepare('SELECT rol_id FROM kullanici_roller WHERE user_id = ? ORDER BY rol_id').all(userId).map(r => r.rol_id),
    atamalar: db.prepare(`SELECT id, teacher_membership_id AS uyelik FROM assignments WHERE teacher_membership_id IN (${ogretmenler}) ORDER BY id`).all().map(a => ({ ...a })),
    siniflar: db.prepare(`SELECT id, homeroom_membership_id AS uyelik FROM classes WHERE homeroom_membership_id IN (${ogretmenler}) ORDER BY id`).all().map(c => ({ ...c })),
  };
}

// Geri alma çakışma denetimi: üyelik, görev ve rol durumu anlık görüntüyle aynı mı? (atama ve sınıf sayıları karşılaştırılmaz)
const durumOzeti = a => JSON.stringify({ u: a.uyelikler, g: a.gorevler, r: a.roller });
export const anlikAyni = (a, b) => durumOzeti(a) === durumOzeti(b);

// Anlık görüntüye dön: üyelik durumları, müdür görevleri, roller; ayrılırken boşalan atama ve sınıf öğretmenlikleri
// yalnızca hâlâ boşsa geri verilir. Dönüş: geri verilemeyen atama/sınıf sayısı.
export function anlikGeriYukle(userId, once) {
  const sonuc = { atlananAtama: 0, atlananSinif: 0 };
  const simdiki = db.prepare(`SELECT id FROM memberships WHERE user_id = ? AND role IN ${PERSONEL}`).all(userId).map(m => m.id);
  const onceIds = new Set(once.uyelikler.map(m => m.id));
  for (const m of once.uyelikler) {
    if (simdiki.includes(m.id)) {
      db.prepare('UPDATE memberships SET status = ?, gorev = ?, branch_id = ?, brans_id = ?, zumre_baskani = ? WHERE id = ?')
        .run(m.durum, m.gorev, m.sube, m.brans, m.baskan, m.id);
      if (m.durum !== 'aktif') db.prepare('DELETE FROM sessions WHERE membership_id = ?').run(m.id);
    }
  }
  // Eylemle açılan üyelikler: silinebiliyorsa silinir, hareketi varsa pasifleştirilir
  for (const id of simdiki.filter(i => !onceIds.has(i))) {
    db.prepare('DELETE FROM sessions WHERE membership_id = ?').run(id);
    db.prepare('DELETE FROM teacher_courses WHERE teacher_membership_id = ?').run(id);
    try { db.prepare('DELETE FROM memberships WHERE id = ?').run(id); }
    catch { db.prepare("UPDATE memberships SET status = 'pasif', zumre_baskani = 0 WHERE id = ?").run(id); }
  }
  db.prepare('DELETE FROM okul_yoneticileri WHERE user_id = ?').run(userId);
  for (const g of once.gorevler) db.prepare('INSERT INTO okul_yoneticileri (branch_id, user_id, gorev, created_at) VALUES (?,?,?,?)').run(g.sube, userId, g.gorev, Date.now());
  db.prepare('DELETE FROM kullanici_roller WHERE user_id = ?').run(userId);
  for (const r of once.roller) {
    if (db.prepare('SELECT 1 FROM roller WHERE id = ?').get(r)) db.prepare('INSERT OR IGNORE INTO kullanici_roller (user_id, rol_id) VALUES (?,?)').run(userId, r);
  }
  for (const a of once.atamalar) {
    if (!Number(db.prepare('UPDATE assignments SET teacher_membership_id = ? WHERE id = ? AND teacher_membership_id IS NULL').run(a.uyelik, a.id).changes)
      && db.prepare('SELECT teacher_membership_id AS t FROM assignments WHERE id = ?').get(a.id)?.t !== a.uyelik) sonuc.atlananAtama++;
  }
  for (const c of once.siniflar) {
    if (!Number(db.prepare('UPDATE classes SET homeroom_membership_id = ? WHERE id = ? AND homeroom_membership_id IS NULL').run(c.uyelik, c.id).changes)
      && db.prepare('SELECT homeroom_membership_id AS t FROM classes WHERE id = ?').get(c.id)?.t !== c.uyelik) sonuc.atlananSinif++;
  }
  zumreRolunuEsitle();
  return sonuc;
}

// Okulun müdür / müdür yardımcısı görevi kaldırılır. Yönetim girişi (o okuldaki 'okul' kapsamlı üyelik) yalnızca
// başka görevi ve hiç rolü kalmadıysa kapanır; başka okullardaki üyeliklere dokunulmaz.
export function mudurGoreviKaldir(userId, subeId) {
  db.prepare('DELETE FROM okul_yoneticileri WHERE branch_id = ? AND user_id = ?').run(subeId, userId);
  if (db.prepare('SELECT 1 FROM okul_yoneticileri WHERE user_id = ? AND branch_id = ?').get(userId, subeId)) return;
  if (db.prepare('SELECT 1 FROM kullanici_roller WHERE user_id = ?').get(userId)) return;
  const kapanan = db.prepare("SELECT id FROM memberships WHERE user_id = ? AND branch_id = ? AND role = 'yonetim' AND gorev = 'okul' AND status = 'aktif'").all(userId, subeId);
  for (const m of kapanan) {
    db.prepare("UPDATE memberships SET status = 'pasif' WHERE id = ?").run(m.id);
    db.prepare('DELETE FROM sessions WHERE membership_id = ?').run(m.id);
  }
}

// Kişinin bir okulda yönetim üyeliği: yoksa 'okul' kapsamlı açılır, pasifse etkinleştirilir (kurum yönetimi üyeliği korunur)
export function yonetimUyeligiAc(userId, subeId) {
  const m = db.prepare("SELECT id, status FROM memberships WHERE user_id = ? AND branch_id = ? AND role = 'yonetim'").get(userId, subeId);
  if (!m) return Number(db.prepare("INSERT INTO memberships (user_id, branch_id, role, gorev) VALUES (?,?,'yonetim','okul')").run(userId, subeId).lastInsertRowid);
  if (m.status !== 'aktif') db.prepare("UPDATE memberships SET status = 'aktif' WHERE id = ?").run(m.id);
  return m.id;
}

// Rolü kalkan ya da silinen kişide: başka nedeni (müdür görevi, başka rol) kalmayan 'okul' kapsamlı yönetim üyelikleri kapanır
export function yetimYonetimiKapat(userId) {
  if (db.prepare('SELECT 1 FROM kullanici_roller WHERE user_id = ?').get(userId)) return 0;
  const aday = db.prepare("SELECT id, branch_id FROM memberships WHERE user_id = ? AND role = 'yonetim' AND gorev = 'okul' AND status = 'aktif'").all(userId)
    .filter(m => !db.prepare('SELECT 1 FROM okul_yoneticileri WHERE user_id = ? AND branch_id = ?').get(userId, m.branch_id));
  // Yönetim üyeliğinden başka hiçbir aktif personel üyeliği kalmıyorsa hesap girişsiz kalmasın diye dokunulmaz
  const baska = db.prepare("SELECT COUNT(*) AS n FROM memberships WHERE user_id = ? AND status = 'aktif'").get(userId).n;
  if (baska <= aday.length) return 0;
  for (const m of aday) {
    db.prepare("UPDATE memberships SET status = 'pasif' WHERE id = ?").run(m.id);
    db.prepare('DELETE FROM sessions WHERE membership_id = ?').run(m.id);
  }
  return aday.length;
}
