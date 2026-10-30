import { db } from './db.js';

export const KADEMELER = ['Anasınıfı', 'İlkokul', 'Ortaokul', 'Lise'];

// İlkokulda sınıfın sorumlusu "sınıf öğretmeni", ortaokul ve lisede "mentor öğretmen" olur.
export const sinifOgretmeniAdi = kademe => (kademe === 'Ortaokul' || kademe === 'Lise' ? 'Mentor öğretmen' : 'Sınıf öğretmeni');
export const sinifOgretmeniAdiSinif = sinifId =>
  sinifOgretmeniAdi(sinifId ? db.prepare('SELECT level FROM classes WHERE id = ?').get(sinifId)?.level : null);

// Kademeye göre ders listeleri: bir sınıfa yalnızca kendi kademesinin dersleri eklenir.
const KADEME_DERSLERI = {
  'Anasınıfı': ['Oyun ve Fiziki Etkinlikler', 'Müzik', 'Görsel Sanatlar', 'İngilizce', 'Serbest Etkinlikler'],
  'İlkokul': ['Türkçe', 'Matematik', 'Hayat Bilgisi', 'Fen Bilimleri', 'Sosyal Bilgiler', 'İngilizce', 'Din Kültürü',
    'Beden Eğitimi', 'Görsel Sanatlar', 'Müzik', 'Bilişim', 'Oyun ve Fiziki Etkinlikler', 'Serbest Etkinlikler'],
  'Ortaokul': ['Türkçe', 'Matematik', 'Fen Bilimleri', 'Sosyal Bilgiler', 'İngilizce', 'Din Kültürü', 'Beden Eğitimi',
    'Görsel Sanatlar', 'Müzik', 'Bilişim', 'T.C. İnkılap Tarihi ve Atatürkçülük', 'Teknoloji ve Tasarım', 'Rehberlik'],
  'Lise': ['Matematik', 'Edebiyat', 'Fizik', 'Kimya', 'Biyoloji', 'Tarih', 'Coğrafya', 'Felsefe', 'İngilizce', 'Din Kültürü',
    'Beden Eğitimi', 'Görsel Sanatlar', 'Müzik', 'Bilişim', 'Rehberlik'],
};

const tabloVardi = db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'ders_kademe'").get();
db.exec(`CREATE TABLE IF NOT EXISTS ders_kademe (
  course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  kademe    TEXT NOT NULL,
  PRIMARY KEY (course_id, kademe)
)`);
if (!tabloVardi) {
  db.exec('BEGIN');
  try {
    const dersVar = db.prepare('INSERT OR IGNORE INTO courses (name) VALUES (?)');
    const dersAra = db.prepare('SELECT id FROM courses WHERE name = ? COLLATE NOCASE');
    const bagla = db.prepare('INSERT OR IGNORE INTO ders_kademe (course_id, kademe) VALUES (?, ?)');
    for (const [kademe, dersler] of Object.entries(KADEME_DERSLERI)) {
      for (const ad of dersler) { if (!dersAra.get(ad)) dersVar.run(ad); bagla.run(dersAra.get(ad).id, kademe); }
    }
    // Listelerde olmayan (yönetimin kendi açtığı) dersler tüm kademelerde kalır
    for (const c of db.prepare('SELECT id FROM courses WHERE id NOT IN (SELECT course_id FROM ders_kademe)').all()) {
      for (const kademe of KADEMELER) bagla.run(c.id, kademe);
    }
    db.exec('COMMIT');
  } catch (e) { db.exec('ROLLBACK'); throw e; }
}

// Anasınıfı ve ilkokulda sınıfı "Sınıf Öğretmenliği" branşındaki öğretmen okutur; bu bir ders değil, branştır.
export const SINIF_OGRETMENLIGI = 'Sınıf Öğretmenliği';
export const SINIF_OGRETMENI_KADEMELERI = ['Anasınıfı', 'İlkokul'];
if (!db.prepare('SELECT 1 FROM courses WHERE name = ? COLLATE NOCASE').get(SINIF_OGRETMENLIGI)) {
  const yeni = db.prepare('INSERT INTO courses (name) VALUES (?)').run(SINIF_OGRETMENLIGI).lastInsertRowid;
  for (const k of SINIF_OGRETMENI_KADEMELERI) db.prepare('INSERT OR IGNORE INTO ders_kademe (course_id, kademe) VALUES (?, ?)').run(yeni, k);
}
export const sinifOgretmenligiId = () => db.prepare('SELECT id FROM courses WHERE name = ? COLLATE NOCASE').get(SINIF_OGRETMENLIGI).id;

// Ders listesi; her ders hangi kademelerde okutuluyorsa onunla birlikte (kaydı olmayan ders her kademede)
export function dersListesi() {
  return db.prepare(`SELECT c.id, c.name AS ad, (SELECT group_concat(kademe, ',') FROM ders_kademe WHERE course_id = c.id) AS kademeler
    FROM courses c ORDER BY c.name`).all().map(d => ({ id: d.id, ad: d.ad, kademeler: d.kademeler ? KADEMELER.filter(k => d.kademeler.split(',').includes(k)) : [...KADEMELER] }));
}

export function dersKademedeMi(dersId, kademe) {
  const kayitli = db.prepare('SELECT 1 FROM ders_kademe WHERE course_id = ?').get(dersId);
  return !kayitli || !!db.prepare('SELECT 1 FROM ders_kademe WHERE course_id = ? AND kademe = ?').get(dersId, kademe);
}

export function dersKademeleriYaz(dersId, kademeler) {
  db.prepare('DELETE FROM ders_kademe WHERE course_id = ?').run(dersId);
  const bagla = db.prepare('INSERT INTO ders_kademe (course_id, kademe) VALUES (?, ?)');
  for (const k of kademeler) bagla.run(dersId, k);
}
