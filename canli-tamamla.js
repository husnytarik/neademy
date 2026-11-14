// Canlı veritabanını TAMAMLAR (kapasite denemesi için): yeni okullar, yeni öğrenci/öğretmenler, okul başından bugüne kadar tüm kayıtlar.
// Mevcut veriyi silmez; yalnızca eksikleri ekler. Kullanım (sunucu kapalıyken, üretim ortamı değişkenleriyle):
//   node --no-warnings canli-tamamla.js
// Sonunda DATA_DIR içine hizli-giris.json yazar (tek tıkla giriş sayfası bunu okur).
import fs from 'node:fs';
import path from 'node:path';
import { deflateSync, crc32 } from 'node:zlib';
import { db, sonrakiOkulNo } from './db.js';
import { ortam } from './ortam.js';
import './gorev.js';
import './duyuru.js';
import './teslim.js';
import './zumrem.js';
import './tatil.js';
import './kurum.js';
import { sistemRolleriKur } from './yetki.js';
import './ogrenci.js';
import { DERS_ZAMANLARI } from './okul-ayar.js';
import { KULUP_DERSI } from './ders-programi.js';
import { dersKazanimlari } from './kazanim.js';

const OKUL_BASI = '2026-09-14';
const TATILLER = new Set(['2026-10-29']);
const KULUP_GUN = 3;
const INKILAP = 'T.C. İnkılap Tarihi ve Atatürkçülük';
const bugun = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
const kaydir = (t, n) => { const d = new Date(t + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
const gunNo = t => new Date(t + 'T00:00:00Z').getUTCDay();
const haftaIci = t => { while (gunNo(t) === 0 || gunNo(t) === 6) t = kaydir(t, -1); return t; };
const zaman = (t, saat) => new Date(`${t}T${saat}:00+03:00`).getTime();
const simdi = Date.now();

let tohum = 20261113;
const rnd = () => (tohum = (tohum * 1664525 + 1013904223) % 4294967296) / 4294967296;
const sec = a => a[Math.floor(rnd() * a.length)];
const karistir = a => { a = [...a]; for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const gauss = () => (rnd() + rnd() + rnd() + rnd() - 2) * 1.2;
const sinirla = (x, a, b) => Math.max(a, Math.min(b, x));
const sure = (ad, f) => { const b = Date.now(); const s = f(); console.log(`  [${((Date.now() - b) / 1000).toFixed(1)} sn] ${ad}`); return s; };

function tcUret(ilk9) {
  const d = ilk9.split('').map(Number);
  const d10 = ((((d[0] + d[2] + d[4] + d[6] + d[8]) * 7) - (d[1] + d[3] + d[5] + d[7])) % 10 + 10) % 10;
  const d11 = (d.reduce((a, b) => a + b, 0) + d10) % 10;
  return ilk9 + d10 + d11;
}

const hazirlar = new Map();
const hazir = sql => hazirlar.get(sql) || (hazirlar.set(sql, db.prepare(sql)), hazirlar.get(sql));
const ins = (sql, ...a) => Number(hazir(sql).run(...a).lastInsertRowid);
const calis = (sql, ...a) => hazir(sql).run(...a);
const tum = (sql, ...a) => hazir(sql).all(...a);
const bir = (sql, ...a) => hazir(sql).get(...a);

// ---------- Sözlükler ----------
const ERKEK = ['Ahmet', 'Mehmet', 'Mustafa', 'Ali', 'Emre', 'Burak', 'Can', 'Deniz', 'Efe', 'Kerem', 'Yusuf', 'Ömer', 'Arda', 'Eren', 'Berk', 'Kaan', 'Mert', 'Onur', 'Barış', 'Cem', 'Doruk', 'Ege',
  'Furkan', 'Giray', 'Hakan', 'İlker', 'Kağan', 'Levent', 'Murat', 'Nihat', 'Orhan', 'Poyraz', 'Rüzgar', 'Selim', 'Tolga', 'Umut', 'Yiğit', 'Zafer', 'Atlas', 'Alp', 'Bora', 'Çağan', 'Emir', 'Fatih', 'Gökhan', 'Halil', 'İbrahim', 'Kemal', 'Metin', 'Nuri', 'Oğuz', 'Rıza', 'Serkan', 'Taner', 'Volkan', 'Yunus'];
const KADIN = ['Ayşe', 'Fatma', 'Zeynep', 'Elif', 'Merve', 'Selin', 'Defne', 'Ecrin', 'Ceren', 'Büşra', 'Naz', 'İrem', 'Yağmur', 'Esra', 'Hira', 'Melis', 'Asya', 'Duru', 'Ela', 'Su', 'Aylin', 'Bahar', 'Cansu',
  'Derya', 'Ebru', 'Feyza', 'Gizem', 'Hande', 'Işıl', 'Jale', 'Kübra', 'Lale', 'Mina', 'Nehir', 'Özge', 'Pelin', 'Rana', 'Sevgi', 'Tuğçe', 'Yasemin', 'Aslı', 'Burcu', 'Çiğdem', 'Dilara', 'Esma', 'Funda', 'Gül', 'Hatice', 'İpek', 'Leyla', 'Meryem', 'Nilay', 'Özlem', 'Pınar', 'Sibel', 'Tuba'];
const SOYAD = ['Yılmaz', 'Kaya', 'Demir', 'Şahin', 'Çelik', 'Yıldız', 'Yıldırım', 'Öztürk', 'Aydın', 'Özdemir', 'Arslan', 'Doğan', 'Kılıç', 'Aslan', 'Çetin', 'Kara', 'Koç', 'Kurt', 'Özkan', 'Şimşek', 'Polat', 'Erdoğan',
  'Güneş', 'Aksoy', 'Acar', 'Tekin', 'Bulut', 'Korkmaz', 'Avcı', 'Türk', 'Bozkurt', 'Karaca', 'Uçar', 'Sönmez', 'Taş', 'Gündüz', 'Bayram', 'Çakır', 'Eroğlu', 'Duman', 'Ateş', 'Yavuz', 'Turan', 'Ekinci', 'Soylu', 'Tunç',
  'Sezer', 'Uysal', 'Başaran', 'Önal', 'Aktaş', 'Bayraktar', 'Cengiz', 'Dinç', 'Ergin', 'Fidan', 'Gür', 'Hızlı', 'İnan', 'Kandemir', 'Işık', 'Zengin', 'Mutlu', 'Özer', 'Yalçın', 'Coşkun', 'Bilgin', 'Karakaya', 'Tuncer', 'Ay'];
const kullanilanAd = new Set(tum('SELECT full_name FROM users').map(r => r.full_name));
function isim(cins, soyad) {
  for (let i = 0; i < 800; i++) {
    const t = sec(cins === 'E' ? ERKEK : KADIN) + ' ' + (soyad || sec(SOYAD));
    if (!kullanilanAd.has(t)) { kullanilanAd.add(t); return t; }
  }
  const t = sec(cins === 'E' ? ERKEK : KADIN) + ' ' + (soyad || sec(SOYAD));
  return t;
}
const ascii = s => s.toLocaleLowerCase('tr').replace(/ç/g, 'c').replace(/ğ/g, 'g').replace(/ı/g, 'i').replace(/ö/g, 'o').replace(/ş/g, 's').replace(/ü/g, 'u').replace(/[^a-z ]/g, '').replace(/\s+/g, '.');

// Şifreli sütunlar: ham değerleri oku (eski düz değerler çözmede hata verir). Çakışma kontrolü için "v1:" değerlerini de olduğu gibi tutuyoruz;
// yeni değerler deterministik şifrelendiğinden, düz metin üzerinden kontrol etmek için çözülebilenleri de ekliyoruz.
import { DatabaseSync } from 'node:sqlite';
const ham = new DatabaseSync(path.join(ortam.veriKlasoru, 'akant.db'), { readOnly: true });
const tcler = new Set(), teller = new Set();
for (const r of ham.prepare('SELECT tc_no, phone FROM users').all()) {
  if (r.tc_no && !String(r.tc_no).startsWith('v1:')) tcler.add(r.tc_no);
  if (r.phone && !String(r.phone).startsWith('v1:')) teller.add(r.phone);
}
const hamTc = new Set(ham.prepare('SELECT tc_no FROM users').all().map(r => r.tc_no));
const hamTel = new Set(ham.prepare('SELECT phone FROM users').all().map(r => r.phone));
ham.close();
// Şifreli (v1:) değerlerin düz karşılığını çözerek ekle
try {
  for (const r of tum("SELECT id FROM users")) { /* satır bazında çöz */
    try { const u = db.prepare('SELECT tc_no, phone FROM users WHERE id = ?').get(r.id); if (u.tc_no) tcler.add(u.tc_no); if (u.phone) teller.add(u.phone); } catch { /* düz eski değer */ }
  }
} catch { /* yoksay */ }
void hamTc; void hamTel;
let kisiSayaci = 30000000;
function kullaniciEkle(ad, ozel = {}) {
  let tc, tel;
  do { tc = tcUret('9' + String(++kisiSayaci).padStart(8, '0')); } while (tcler.has(tc));
  tcler.add(tc);
  do { tel = '56' + String(kisiSayaci).padStart(8, '0'); kisiSayaci++; } while (teller.has(tel));
  teller.add(tel);
  const uid = ins('INSERT INTO users (tc_no, phone, full_name, created_at, foto) VALUES (?,?,?,?,?)', tc, tel, ad, simdi, ozel.foto ?? null);
  return { uid, ad, tc, tel };
}
const uyeEkle = (k, subeId, rol, okulNo = null, gorev = null) =>
  ({ ...k, mid: ins('INSERT INTO memberships (user_id, branch_id, role, okul_no, gorev) VALUES (?,?,?,?,?)', k.uid, subeId, rol, okulNo, gorev ?? 'kurum') });

const dersIdleri = new Map(tum('SELECT id, name FROM courses').map(r => [r.name, r.id]));
const dersId = ad => dersIdleri.get(ad) ?? (dersIdleri.set(ad, ins('INSERT INTO courses (name) VALUES (?)', ad)), dersIdleri.get(ad));
const rolId = kod => bir('SELECT id FROM roller WHERE kod = ?', kod).id;
const rolVer = (uid, kod) => calis('INSERT OR IGNORE INTO kullanici_roller (user_id, rol_id) VALUES (?,?)', uid, rolId(kod));

// ---------- Düzeye göre haftalık ders saatleri (canlıdaki mevcut atamalardan) ----------
const PROGRAM = {};
for (const r of tum(`SELECT CAST(c.name AS INTEGER) d, co.name ders, MAX(a.weekly_hours) h FROM assignments a JOIN classes c ON c.id = a.class_id JOIN courses co ON co.id = a.course_id
                     WHERE co.name != ? AND CAST(c.name AS INTEGER) > 0 GROUP BY 1, 2`, KULUP_DERSI)) (PROGRAM[r.d] ??= {})[r.ders] = r.h;
PROGRAM[0] = { 'Oyun ve Fiziki Etkinlikler': 10, 'Serbest Etkinlikler': 8, 'Müzik': 2, 'Görsel Sanatlar': 2, 'İngilizce': 3 };
for (let d = 1; d <= 12; d++) if (!PROGRAM[d]) throw new Error('Düzey ' + d + ' için canlıda ders programı bulunamadı');
const GRUPLAR = [['Türkçe'], ['Matematik'], ['Fen Bilimleri'], ['Sosyal Bilgiler', INKILAP], ['İngilizce'], ['Din Kültürü'], ['Beden Eğitimi'], ['Görsel Sanatlar', 'Müzik'], ['Bilişim', 'Teknoloji ve Tasarım'],
  ['Edebiyat'], ['Fizik'], ['Kimya'], ['Biyoloji'], ['Tarih'], ['Coğrafya'], ['Felsefe'], ['Rehberlik'], ['Hayat Bilgisi'], ['Oyun ve Fiziki Etkinlikler', 'Serbest Etkinlikler']];
const SINIF_OGR_DERSLERI = ['Türkçe', 'Matematik', 'Hayat Bilgisi', 'Fen Bilimleri', 'Sosyal Bilgiler', 'Oyun ve Fiziki Etkinlikler', 'Serbest Etkinlikler'];
const ODEVSIZ = new Set(['Rehberlik', 'Serbest Etkinlikler', 'Oyun ve Fiziki Etkinlikler', 'Sınıf Öğretmenliği']);

// ---------- Okul modeli ----------
const okullar = [];
const siniflarId = new Map();
const ogrById = new Map(); // öğrenci mid -> öğrenci
const veliUidleri = new Map(); // öğrenci mid -> [veli uid]
const kayitliOkulAdlari = new Map();

function ogrenciNesnesi(k, cins, sinif, okul) {
  const r = rnd();
  const o = { ...k, cins, sinif, okul, yet: { genel: gauss() * 0.9, ders: {} }, egilim: r < 0.12 ? 0.07 : r < 0.15 ? 0.14 : 0.012, caliskan: rnd() < 0.55 ? 0.97 : rnd() < 0.65 ? 0.88 : 0.7 };
  sinif.ogrenciler.push(o); okul.ogrenciler.push(o); ogrById.set(o.mid, o);
  return o;
}

function mevcutOkulYukle(b) {
  const o = { id: b.id, ad: b.name, tur: b.tur, kampusId: b.campus_id, mevcut: true, siniflar: [], ogrenciler: [], ogretmenler: [], programSatirlari: [], yon: [], t: new Map(), duzeyler: new Set() };
  o.ilk = b.tur === 'İlkokul' || b.tur === 'Anaokulu';
  const kayitCins = new Map(tum(`SELECT student_membership_id m, cinsiyet c FROM ogrenci_kayit`).map(r => [r.m, r.c]));
  for (const c of tum('SELECT * FROM classes WHERE branch_id = ? ORDER BY id', b.id)) {
    const s = { id: c.id, ad: c.name, duzey: parseInt(c.name, 10) || 0, level: c.level, o, ogrenciler: [], atama: {}, rehberMid: c.homeroom_membership_id };
    o.siniflar.push(s); siniflarId.set(s.id, s); o.duzeyler.add(s.duzey);
    for (const x of tum(`SELECT m.id mid, m.user_id uid, u.full_name ad FROM class_students cs JOIN memberships m ON m.id = cs.student_membership_id JOIN users u ON u.id = m.user_id WHERE cs.class_id = ? ORDER BY u.full_name`, c.id)) {
      const kc = kayitCins.get(x.mid);
      const cins = kc === 'erkek' ? 'E' : kc === 'kiz' ? 'K' : KADIN.includes(x.ad.split(' ')[0]) ? 'K' : 'E';
      ogrenciNesnesi({ mid: x.mid, uid: x.uid, ad: x.ad }, cins, s, o);
    }
  }
  const tm = new Map();
  for (const t of tum(`SELECT DISTINCT m.id mid, m.user_id uid, u.full_name ad FROM assignments a JOIN classes c ON c.id = a.class_id JOIN memberships m ON m.id = a.teacher_membership_id JOIN users u ON u.id = m.user_id WHERE c.branch_id = ?`, b.id))
    tm.set(t.mid, { mid: t.mid, uid: t.uid, ad: t.ad, dersler: [], yuk: 0 });
  o.ogretmenler = [...tm.values()];
  for (const a of tum(`SELECT a.id, a.class_id, co.name ders, a.teacher_membership_id tm, a.weekly_hours saat FROM assignments a JOIN classes c ON c.id = a.class_id JOIN courses co ON co.id = a.course_id WHERE c.branch_id = ? AND co.name != ?`, b.id, KULUP_DERSI)) {
    const s = siniflarId.get(a.class_id), ogr = tm.get(a.tm);
    if (!ogr) continue;
    s.atama[a.ders] = { id: a.id, ders: a.ders, ogr, saat: a.saat, sinif: s };
    if (!ogr.dersler.includes(a.ders)) ogr.dersler.push(a.ders);
    ogr.yuk += a.saat;
  }
  const atamaIdden = new Map();
  for (const s of o.siniflar) for (const a of Object.values(s.atama)) atamaIdden.set(a.id, a);
  for (const r of tum(`SELECT sc.class_id, sc.day, sc.period, sc.assignment_id FROM schedule sc JOIN classes c ON c.id = sc.class_id WHERE c.branch_id = ?`, b.id)) {
    const a = atamaIdden.get(r.assignment_id);
    if (a) o.programSatirlari.push({ sinif: a.sinif, gun: r.day, saat: r.period, atama: a });
  }
  const mud = bir(`SELECT m.id mid, m.user_id uid FROM okul_yoneticileri y JOIN memberships m ON m.user_id = y.user_id AND m.branch_id = y.branch_id AND m.role = 'yonetim' WHERE y.branch_id = ? AND y.gorev = 'mudur'`, b.id);
  if (mud) o.mudurMid = mud.mid;
  o.kulupSaati = bir(`SELECT MIN(ders_saati) s FROM kulupler WHERE branch_id = ?`, b.id)?.s ?? (b.tur === 'İlkokul' ? 5 : b.tur === 'Lise' ? 8 : 6);
  return o;
}

// ---------- Aile / kayıt yardımcıları ----------
const KAN = ['0 Rh+', 'A Rh+', 'B Rh+', 'AB Rh+', 'A Rh-', '0 Rh-', 'B Rh-', 'AB Rh-'];
const ONCEKI = ['Güneş İlkokulu', 'Atatürk Ortaokulu', 'Bahçelievler İlkokulu', 'Deniz Koleji', 'Cumhuriyet Ortaokulu', 'Zafer Lisesi'];
const MESLEK = ['Mühendis', 'Öğretmen', 'Esnaf', 'Doktor', 'Memur', 'Serbest meslek', 'Avukat', 'Hemşire', 'Muhasebeci', 'Çiftçi', 'Turizmci'];
const ILCE = { 1: 'Muratpaşa', 2: 'Alanya', 3: 'Manavgat' };
function ogrenciKaydi(ogr) {
  const id = ogr.mid, duzey = ogr.sinif.duzey;
  const yas = duzey === 0 ? 4 + (ogr.sinif.ad.length % 2) : duzey + 6;
  const dogum = `${2026 - yas}-${String(1 + (id * 7) % 12).padStart(2, '0')}-${String(1 + (id * 11) % 28).padStart(2, '0')}`;
  const nakil = id % 7 === 0 && duzey > 1;
  const tur = nakil ? 'nakil' : duzey <= 1 || id % 11 === 0 ? 'yeni' : 'yenileme';
  const onceki = nakil || (tur === 'yeni' && duzey > 1) ? ONCEKI[id % ONCEKI.length] : '';
  calis('INSERT OR IGNORE INTO ogrenci_kayit (student_membership_id, dogum_tarihi, dogum_yeri, cinsiyet, kan_grubu, onceki_okul, kayit_tarihi, kayit_turu, yemek, guncelleme) VALUES (?,?,?,?,?,?,?,?,?,?)',
    id, dogum, ['Antalya', 'Alanya', 'Manavgat', 'Isparta'][id % 4], ogr.cins === 'E' ? 'erkek' : 'kiz', KAN[id % KAN.length], onceki, tur === 'yenileme' ? '2026-06-15' : '2026-08-25', tur, id % 5 === 0 ? 'almayacak' : 'alacak', simdi);
  if (!bir('SELECT 1 x FROM ogrenci_ozel_durum WHERE student_membership_id = ?', id)) {
    const ozel = id % 9 === 0 ? [['alerji', 'Fıstık alerjisi', 'Okul yemeklerinde ve kulüp ikramlarında fıstık olmamalı.']]
      : id % 13 === 0 ? [['saglik', 'Astım', 'Spor derslerinde ilacı yanında bulunur; nefes darlığında aile bilgilendirilir.']]
      : id % 17 === 0 ? [['saglik', 'Gözlük kullanıyor', 'Ön sıralarda oturması önerilir.']] : [];
    for (const [t, b, a] of ozel) calis('INSERT INTO ogrenci_ozel_durum (student_membership_id, tur, baslik, aciklama, created_at) VALUES (?,?,?,?,?)', id, t, b, a, simdi);
  }
}
const profil = (uid, ek) => calis(`INSERT OR IGNORE INTO profil_bilgi (user_id, email, telefon2, il, ilce, adres, yakin_ad, yakin_yakinlik, yakin_telefon, guncelleme) VALUES (?,?,?,?,?,?,?,?,?,?)`,
  uid, ek.email ?? '', ek.telefon2 ?? '', 'Antalya', ek.ilce ?? 'Muratpaşa', ek.adres ?? '', ek.yakinAd ?? '', ek.yakinYakinlik ?? '', ek.yakinTel ?? '', simdi);
const telRast = () => '5' + String(30 + Math.floor(rnd() * 10)) + String(1000000 + Math.floor(rnd() * 8999999));
const adresUret = o => `${o.mahalle || 'Merkez'} Mah. ${100 + Math.floor(rnd() * 800)}. Sk. No: ${1 + Math.floor(rnd() * 60)}`;
let epostaSay = 0;
const epostaUret = ad => `${ascii(ad)}${++epostaSay}@ornek.example`;

// ---------- Okul kurma (yeni okullar) ----------
const KAMPUS_ADRES = { 1: 'Ana Kampüs, Antalya', 2: 'Alanya', 3: 'Manavgat' };
const TANIMLAR = [
  { id: 5, ad: 'Manavgat İlkokulu', tur: 'İlkokul', kampusId: 3, kod: '0705', mahalle: 'Manavgat', sinifSet: [1, 2, 3, 4], harfler: ['A', 'B', 'C'] },
  { id: 6, ad: 'Manavgat Lisesi', tur: 'Lise', kampusId: 3, kod: '0706', mahalle: 'Manavgat', sinifSet: [9, 10, 11, 12], harfler: ['A', 'B', 'C'] },
  { ad: 'Manavgat Ortaokulu', tur: 'Ortaokul', kampusId: 3, kod: '0709', mahalle: 'Manavgat', sinifSet: [5, 6, 7, 8], harfler: ['A', 'B', 'C'] },
  { ad: 'Alanya İlkokulu', tur: 'İlkokul', kampusId: 2, kod: '0710', mahalle: 'Alanya', sinifSet: [1, 2, 3, 4], harfler: ['A', 'B'] },
  { ad: 'Pilot Anaokulu', tur: 'Anaokulu', kampusId: 1, kod: '0711', mahalle: 'Muratpaşa', sinifSet: [0], harfler: ['Papatya', 'Lale', 'Kardelen'], mevcut: 16 },
];
const OKUL_ACIKLAMA = {
  'Anaokulu': ad => `${ad}, 4-5 yaş grubunda oyunla öğrenmeyi, sanatı ve hareketi merkeze alan bir eğitim sunar. Küçük gruplarda, her çocuğun hızına uygun ve güvenli bir ortamda ilk okul deneyimini yaşatır.`,
  'İlkokul': ad => `${ad}, 1-4. sınıflarda okuma yazma, sayı duygusu ve merak üzerine kurulu bir eğitim sunar. Sınıf öğretmenimiz öğrencilerimizi tüm gün tanır ve her çocuğun gelişimini veliyle birlikte izler.`,
  'Ortaokul': ad => `${ad}, 5-8. sınıflarda alan öğretmenleriyle çalışır; LGS hazırlığını yıl boyunca yayılan düzenli sınavlar, etütler ve kulüp saatleriyle dengeler.`,
  'Lise': ad => `${ad}, 9-12. sınıflarda akademik başarıyı sosyal kulüpler, rehberlik ve üniversite hazırlık programıyla birlikte yürütür.`,
};

function yeniOkulKur(t) {
  const kampus = bir('SELECT * FROM kampusler WHERE id = ?', t.kampusId);
  let id = t.id;
  if (!id) id = ins('INSERT INTO branches (name, campus_id, tur) VALUES (?,?,?)', t.ad, t.kampusId, t.tur);
  const slug = ascii(t.ad).replace(/\./g, '');
  calis('UPDATE branches SET kurum_kodu = ?, telefon = ?, eposta = ?, adres = ?, web = ?, aciklama = ?, sosyal = ? WHERE id = ?', t.kod, `0242 ${t.kod.padEnd(7, '0').slice(0, 3)} ${String(10 + id).padStart(2, '0')} ${String(20 + id)}`,
    `${slug}@neademy.example`, `${t.mahalle}, ${kampus.name}`, `${slug}.neademy.example`, OKUL_ACIKLAMA[t.tur](t.ad), JSON.stringify({ instagram: `https://www.instagram.com/${slug}` }), id);
  const kademe = t.tur === 'Anaokulu' ? 'Anasınıfı' : t.tur;
  const o = { id, ad: t.ad, tur: t.tur, kampusId: t.kampusId, mevcut: false, mahalle: t.mahalle, siniflar: [], ogrenciler: [], ogretmenler: [], programSatirlari: [], yon: [], t: new Map(),
    ilk: t.tur === 'İlkokul' || t.tur === 'Anaokulu', duzeyler: new Set(t.sinifSet), kulupSaati: t.tur === 'İlkokul' ? 5 : t.tur === 'Lise' ? 8 : 6 };
  const mevcutN = t.tur === 'Anaokulu' ? 16 : 24;
  for (const duzey of t.sinifSet) for (const harf of t.harfler) {
    const ad = duzey === 0 ? harf : `${duzey}-${harf}`;
    const sid = ins('INSERT INTO classes (branch_id, level, name) VALUES (?,?,?)', id, kademe, ad);
    const s = { id: sid, ad, duzey, level: kademe, o, ogrenciler: [], atama: {} };
    siniflarId.set(sid, s); o.siniflar.push(s);
    const adlar = Array.from({ length: mevcutN + Math.floor(rnd() * 3) - 1 }, () => { const c = sec(['E', 'K']); return { cins: c, ad: isim(c) }; });
    adlar.sort((a, b) => a.ad.localeCompare(b.ad, 'tr'));
    for (const x of adlar) {
      const k = uyeEkle(kullaniciEkle(x.ad), id, 'ogrenci', sonrakiOkulNo(id));
      calis('INSERT INTO class_students (class_id, student_membership_id) VALUES (?,?)', sid, k.mid);
      ogrenciNesnesi(k, x.cins, s, o);
    }
  }
  okullar.push(o);
  return o;
}

// Öğretmen kadrosu: ders grubuna göre saat bütçesiyle (≈21 saat) bölünür; ilkokul/anaokulunda sınıf öğretmeni vardır
function ogretmenEkle(o, dersler) {
  const k = uyeEkle(kullaniciEkle(isim(sec(['E', 'K']))), o.id, 'ogretmen');
  for (const d of dersler) calis('INSERT OR IGNORE INTO teacher_courses (teacher_membership_id, course_id) VALUES (?,?)', k.mid, dersId(d));
  calis('UPDATE memberships SET brans_id = ? WHERE id = ?', dersId(dersler[0]), k.mid);
  k.dersler = [...dersler]; k.yuk = 0; k.yeni = true;
  o.ogretmenler.push(k);
  return k;
}
function kadroKur(o) {
  const sinifOgr = o.ilk;
  const atamaKur = (s, ders, saat, ogr) => {
    const id = ins('INSERT INTO assignments (class_id, course_id, teacher_membership_id, weekly_hours) VALUES (?,?,?,?)', s.id, dersId(ders), ogr.mid, saat);
    s.atama[ders] = { id, ders, ogr, saat, sinif: s }; ogr.yuk += saat;
  };
  if (sinifOgr) for (const s of o.siniflar) {
    const dersler = Object.keys(PROGRAM[s.duzey]).filter(d => SINIF_OGR_DERSLERI.includes(d));
    s.sinifOgretmeni = ogretmenEkle(o, [s.duzey === 0 ? 'Oyun ve Fiziki Etkinlikler' : 'Sınıf Öğretmenliği', ...dersler.filter(d => d !== 'Sınıf Öğretmenliği')]);
    calis('UPDATE memberships SET brans_id = ? WHERE id = ?', dersId(s.duzey === 0 ? 'Oyun ve Fiziki Etkinlikler' : 'Sınıf Öğretmenliği'), s.sinifOgretmeni.mid);
    for (const d of dersler) atamaKur(s, d, PROGRAM[s.duzey][d], s.sinifOgretmeni);
  }
  for (const grup of GRUPLAR) {
    const saatler = o.siniflar.map(s => ({ s, dersler: Object.keys(PROGRAM[s.duzey]).filter(d => grup.includes(d) && !(sinifOgr && SINIF_OGR_DERSLERI.includes(d))) })).filter(x => x.dersler.length);
    if (!saatler.length) continue;
    const toplam = saatler.reduce((a, x) => a + x.dersler.reduce((b, d) => b + PROGRAM[x.s.duzey][d], 0), 0);
    const n = Math.max(1, Math.ceil(toplam / 21));
    const hocalar = Array.from({ length: n }, () => ogretmenEkle(o, grup.filter(d => saatler.some(x => x.dersler.includes(d)))));
    for (const x of saatler.sort((a, b) => a.s.duzey - b.s.duzey || a.s.ad.localeCompare(b.s.ad))) {
      const h = hocalar.reduce((a, b) => (b.yuk < a.yuk ? b : a));
      for (const d of x.dersler) atamaKur(x.s, d, PROGRAM[x.s.duzey][d], h);
    }
  }
  // Rehber / mentör sınıf öğretmeni
  const mentor = o.ogretmenler.filter(t => ['Türkçe', 'Matematik', 'Fen Bilimleri', 'Edebiyat', 'Fizik', 'Tarih', 'İngilizce', 'Sosyal Bilgiler', 'Kimya', 'Biyoloji'].includes(t.dersler[0]));
  o.siniflar.forEach((s, i) => {
    s.rehber = sinifOgr ? s.sinifOgretmeni : mentor[i % mentor.length];
    s.rehberMid = s.rehber.mid;
    calis('UPDATE classes SET homeroom_membership_id = ? WHERE id = ?', s.rehber.mid, s.id);
    s.kulupAtama = !sinifOgr || s.duzey > 0 ? ins('INSERT INTO assignments (class_id, course_id, teacher_membership_id, weekly_hours) VALUES (?,?,NULL,1)', s.id, dersId(KULUP_DERSI)) : null;
  });
  for (const t of o.ogretmenler) calis('INSERT OR REPLACE INTO ogretmen_ayar (user_id, haftalik_azami) VALUES (?,?)', t.uid, Math.max(24, t.yuk + 2));
  // Zümre başkanları
  const gorulen = new Set();
  for (const t of o.ogretmenler) {
    const ders = t.dersler.find(d => !gorulen.has(d) && d !== 'Sınıf Öğretmenliği');
    if (!ders || o.ilk) continue;
    t.dersler.forEach(d => gorulen.add(d));
    calis('UPDATE memberships SET zumre_baskani = 1 WHERE id = ?', t.mid); rolVer(t.uid, 'zumre'); t.zumreBaskani = true;
  }
  if (o.ilk) {
    const ilkDersler = new Set();
    for (const t of o.ogretmenler) if (!t.dersler.some(d => d === 'Sınıf Öğretmenliği' || d === 'Oyun ve Fiziki Etkinlikler' && o.tur === 'Anaokulu' && false) && !ilkDersler.has(t.dersler[0])) { ilkDersler.add(t.dersler[0]); calis('UPDATE memberships SET zumre_baskani = 1 WHERE id = ?', t.mid); rolVer(t.uid, 'zumre'); t.zumreBaskani = true; }
    const ilkSinif = o.ogretmenler.filter(t => t.dersler[0] === 'Sınıf Öğretmenliği' || (o.tur === 'Anaokulu' && t.dersler[0] === 'Oyun ve Fiziki Etkinlikler'))[0];
    if (ilkSinif) { calis('UPDATE memberships SET zumre_baskani = 1 WHERE id = ?', ilkSinif.mid); rolVer(ilkSinif.uid, 'zumre'); ilkSinif.zumreBaskani = true; }
  }
}

// ---------- Yönetim, rehber, güvenlik ----------
const kisiRef = {}; // hızlı giriş için kişiler
function yonetimKur(o) {
  if (!tum('SELECT 1 FROM okul_yoneticileri WHERE branch_id = ?', o.id).length) {
    const m = uyeEkle(kullaniciEkle(isim('E')), o.id, 'yonetim', null, 'okul');
    calis('INSERT INTO okul_yoneticileri (branch_id, user_id, gorev, created_at) VALUES (?,?,?,?)', o.id, m.uid, 'mudur', simdi);
    o.mudurMid = m.mid; o.mudur = m;
    const y1 = uyeEkle(kullaniciEkle(isim('K')), o.id, 'yonetim', null, 'okul');
    const y2 = uyeEkle(kullaniciEkle(isim('E')), o.id, 'yonetim', null, 'okul');
    calis('INSERT INTO okul_yoneticileri (branch_id, user_id, gorev, created_at) VALUES (?,?,?,?)', o.id, y1.uid, 'mudur_yrd', simdi);
    calis('INSERT INTO okul_yoneticileri (branch_id, user_id, gorev, created_at) VALUES (?,?,?,?)', o.id, y2.uid, 'mudur_yrd', simdi);
    o.mudurYrd = y1;
  } else {
    const y = bir(`SELECT m.id mid, m.user_id uid, u.full_name ad FROM okul_yoneticileri y JOIN memberships m ON m.user_id = y.user_id AND m.branch_id = y.branch_id AND m.role = 'yonetim' JOIN users u ON u.id = m.user_id WHERE y.branch_id = ? AND y.gorev = 'mudur' AND u.full_name NOT LIKE '%Husny%' AND u.full_name NOT LIKE 'Test%'`, o.id);
    if (y) { o.mudurMid = y.mid; o.mudur = { mid: y.mid, uid: y.uid, ad: y.ad }; }
    const y2 = bir(`SELECT m.id mid, m.user_id uid, u.full_name ad FROM okul_yoneticileri y JOIN memberships m ON m.user_id = y.user_id AND m.branch_id = y.branch_id AND m.role = 'yonetim' JOIN users u ON u.id = m.user_id WHERE y.branch_id = ? AND y.gorev = 'mudur_yrd' AND u.full_name NOT LIKE '%Husny%' AND u.full_name NOT LIKE 'Test%'`, o.id);
    if (y2) o.mudurYrd = { mid: y2.mid, uid: y2.uid, ad: y2.ad };
  }
  if (!o.mudurMid) { // yalnızca yönetim üyeliği olan okul: bir yönetim üyeliğini kullan
    const y = bir(`SELECT m.id mid, m.user_id uid, u.full_name ad FROM memberships m JOIN users u ON u.id = m.user_id WHERE m.branch_id = ? AND m.role = 'yonetim' ORDER BY m.id LIMIT 1`, o.id);
    o.mudurMid = y.mid; o.mudur = { mid: y.mid, uid: y.uid, ad: y.ad };
  }
  const rolVarMi = kod => bir(`SELECT 1 x FROM kullanici_roller k JOIN roller r ON r.id = k.rol_id JOIN memberships m ON m.user_id = k.user_id JOIN users u ON u.id = m.user_id WHERE r.kod = ? AND m.branch_id = ? AND m.role = 'yonetim' AND u.full_name NOT LIKE '%Husny%' AND u.full_name NOT LIKE 'Test%'`, kod, o.id);
  const yonetimRol = (kod, cins) => { const k = uyeEkle(kullaniciEkle(isim(cins)), o.id, 'yonetim', null, 'okul'); rolVer(k.uid, kod); return k; };
  sistemRolleriKur();
  if (!rolVarMi('rehber')) o.rehber = yonetimRol('rehber', 'K');
  if (!rolVarMi('guvenlik')) { o.guvenlik = yonetimRol('guvenlik', 'E'); yonetimRol('guvenlik', 'E'); }
  if (!o.guvenlik) {
    const g = bir(`SELECT m.id mid, m.user_id uid, u.full_name ad FROM kullanici_roller k JOIN roller r ON r.id = k.rol_id JOIN memberships m ON m.user_id = k.user_id AND m.branch_id = ? AND m.role = 'yonetim' JOIN users u ON u.id = m.user_id WHERE r.kod = 'guvenlik' AND u.full_name NOT LIKE '%Husny%' AND u.full_name NOT LIKE 'Test%' LIMIT 1`, o.id);
    if (g) o.guvenlik = { mid: g.mid, uid: g.uid, ad: g.ad };
  }
  if (!o.rehber) {
    const g = bir(`SELECT m.id mid, m.user_id uid, u.full_name ad FROM kullanici_roller k JOIN roller r ON r.id = k.rol_id JOIN memberships m ON m.user_id = k.user_id AND m.branch_id = ? AND m.role = 'yonetim' JOIN users u ON u.id = m.user_id WHERE r.kod = 'rehber' AND u.full_name NOT LIKE '%Husny%' AND u.full_name NOT LIKE 'Test%' LIMIT 1`, o.id);
    if (g) o.rehber = { mid: g.mid, uid: g.uid, ad: g.ad };
  }
}

// ---------- Haftalık ders programı (yeni okullar) ----------
function programYap(liste) {
  const busy = new Set(), sinifDolu = new Set(), sinifGunYuku = new Map(), atamaGun = new Map();
  const yuk = (s, g) => sinifGunYuku.get(`${s.id}-${g}`) || 0;
  const satirlar = [];
  let yerlesmeyen = 0;
  const dolu = (uid, g, p) => busy.has(`${uid}-${g}-${p}`);
  for (const o of liste) {
    // nöbet: her gün farklı bir öğretmenin 2. saati dolu
    const nobetciler = o.ogretmenler.filter(t => t.yeni);
    o.nobetler = [];
    for (let g = 1; g <= 5; g++) { const t = nobetciler[(g * 3) % nobetciler.length]; if (t) { busy.add(`${t.uid}-${g}-2`); o.nobetler.push({ t, g, saat: 2, ad: 'Bahçe nöbeti', yer: 'Okul bahçesi' }); } }
    for (let g = 1; g <= 5; g++) { const t = nobetciler[(g * 5 + 1) % nobetciler.length]; if (t && !dolu(t.uid, g, 5)) { busy.add(`${t.uid}-${g}-5`); o.nobetler.push({ t, g, saat: 5, ad: 'Yemekhane nöbeti', yer: 'Yemekhane' }); } }
    for (const s of o.siniflar) {
      if (!s.kulupAtama) continue;
      calis('INSERT INTO schedule (class_id, day, period, assignment_id) VALUES (?,?,?,?)', s.id, KULUP_GUN, o.kulupSaati, s.kulupAtama);
      sinifDolu.add(`${s.id}-${KULUP_GUN}-${o.kulupSaati}`); sinifGunYuku.set(`${s.id}-${KULUP_GUN}`, 1);
    }
  }
  const AGIR = new Set(['Türkçe', 'Matematik', 'Fen Bilimleri', 'Hayat Bilgisi', 'Edebiyat', 'Fizik', 'Kimya', 'Biyoloji']);
  const parcalar = [];
  for (const o of liste) for (const s of o.siniflar) for (const a of Object.values(s.atama)) for (let i = 0; i < a.saat; i++) parcalar.push(a);
  for (const a of karistir(parcalar)) {
    const s = a.sinif, enSon = s.o.tur === 'Lise' ? 9 : s.o.tur === 'Ortaokul' ? 8 : 7;
    let en = null;
    for (let g = 1; g <= 5; g++) for (let p = 1; p <= enSon; p++) {
      if (sinifDolu.has(`${s.id}-${g}-${p}`) || dolu(a.ogr.uid, g, p)) continue;
      const ayniGun = atamaGun.get(`${a.id}-${g}`) || 0;
      const puan = ayniGun * 100 + yuk(s, g) * 9 + p + (AGIR.has(a.ders) ? 0 : p > 4 ? -2 : 3);
      if (!en || puan < en.puan) en = { g, p, puan };
    }
    if (!en) { yerlesmeyen++; continue; }
    calis('INSERT INTO schedule (class_id, day, period, assignment_id) VALUES (?,?,?,?)', s.id, en.g, en.p, a.id);
    sinifDolu.add(`${s.id}-${en.g}-${en.p}`); busy.add(`${a.ogr.uid}-${en.g}-${en.p}`);
    sinifGunYuku.set(`${s.id}-${en.g}`, yuk(s, en.g) + 1);
    atamaGun.set(`${a.id}-${en.g}`, (atamaGun.get(`${a.id}-${en.g}`) || 0) + 1);
    s.o.programSatirlari.push({ sinif: s, gun: en.g, saat: en.p, atama: a });
  }
  // Boşlukları kapat
  for (let tur = 0; tur < 6; tur++) {
    let tasindi = 0;
    for (const o of liste) for (const r of [...o.programSatirlari].sort((x, y) => y.saat - x.saat)) {
      const s = r.sinif;
      for (let p = 1; p < r.saat; p++) {
        if (sinifDolu.has(`${s.id}-${r.gun}-${p}`) || dolu(r.atama.ogr.uid, r.gun, p)) continue;
        calis('UPDATE schedule SET period = ? WHERE class_id = ? AND day = ? AND period = ?', p, s.id, r.gun, r.saat);
        sinifDolu.delete(`${s.id}-${r.gun}-${r.saat}`); busy.delete(`${r.atama.ogr.uid}-${r.gun}-${r.saat}`);
        sinifDolu.add(`${s.id}-${r.gun}-${p}`); busy.add(`${r.atama.ogr.uid}-${r.gun}-${p}`);
        r.saat = p; tasindi++;
        break;
      }
    }
    if (!tasindi) break;
  }
  return yerlesmeyen;
}

// ---------- Müfredat ilerlemesi ----------
const KONULAR = ['Konu tekrarı', 'Yeni konu anlatımı', 'Alıştırmalar', 'Uygulama çalışması', 'Soru çözümü', 'Değerlendirme', 'Grup çalışması'];
const ANAOKULU_KONULAR = ['Sonbahar etkinliği', 'Renkler ve şekiller', 'Parmak oyunları', 'Hikâye saati', 'Hayvanlar ve sesleri', 'Müzik ve ritim', 'Boyama çalışması', 'Sayılar ve sayma oyunu', 'Hareketli oyunlar', 'Resim çalışması'];
const kazIlerleme = new Map();
for (const r of tum('SELECT assignment_id a, COUNT(*) n FROM konular GROUP BY 1')) kazIlerleme.set(r.a, { liste: null, n: r.n });
const kazMetni = x => ((x.kod ? x.kod + ' – ' : '') + x.metin.replace(/-\s+/g, '')).slice(0, 300);
const kisalt = (m, n = 110) => (m.length > n ? m.slice(0, n - 3).replace(/\s+\S*$/, '') + '…' : m);
function sonrakiKonu(a) {
  let k = kazIlerleme.get(a.id);
  if (!k) { k = { liste: null, n: 0 }; kazIlerleme.set(a.id, k); }
  if (!k.liste) k.liste = a.sinif.duzey > 0 ? dersKazanimlari(a.ders, a.sinif.duzey) : [];
  const sira = k.n++;
  if (!k.liste.length) { const h = a.sinif.duzey === 0 ? ANAOKULU_KONULAR : KONULAR; return { konu: h[(sira + a.id) % h.length], kazanim: null }; }
  const j = Math.floor(sira / 2);
  const x = k.liste[(j + Math.floor(j / 8)) % k.liste.length];
  const metin = x.metin.replace(/-\s+/g, '');
  return { konu: (sira % 2 ? 'Pekiştirme: ' : '') + kisalt(metin, sira % 2 ? 96 : 110), kazanim: kazMetni(x) };
}

const ODEVLER = {
  'Türkçe': [['Okuma günlüğü: bir bölüm özeti', 'Okuduğun kitabın bu haftaki bölümünü 5-6 cümleyle özetle. Bölümde geçen yeni 5 kelimeyi anlamlarıyla birlikte defterine yaz.'],
    ['Paragraf soruları', 'Çalışma kitabındaki paragraf sorularını çöz. Her sorunun yanına ana fikri bulduğun cümleyi yaz.'],
    ['Kısa yazı: Hayalimdeki okul', 'Hayalindeki okulu anlatan 8-10 cümlelik bir yazı yaz. En az üç sıfat ve iki bağlaç kullan, noktalama işaretlerine dikkat et.'],
    ['Yazım kuralları alıştırması', 'Çalışma kâğıdındaki yazım ve noktalama alıştırmalarını tamamla; yanlış yazdığın sözcükleri üçer kez defterine yaz.']],
  'Matematik': [['Problem seti', 'Çalışma kâğıdındaki 10 problemi defterine çöz. İşlem basamaklarını yaz, sonucu cümleyle belirt.'],
    ['Ders kitabı alıştırmaları', 'Ders kitabındaki alıştırmaları çöz. Çözemediğin soruların numarasını işaretle, derste birlikte bakacağız.'],
    ['Günlük hayattan matematik', 'Evde ya da markette gördüğün üç durumu matematik problemine dönüştür ve çözümünü yaz.'],
    ['Tekrar testi', 'Test kitabındaki konu tekrarı sayfasını zaman tutarak çöz. Süreni ve yanlış sorularını not et.']],
  'Hayat Bilgisi': [['Ailemle bir gün', 'Ailenle yaptığın bir etkinliği anlatan resim çiz ve altına iki cümle yaz.'], ['Mahallemizdeki meslekler', 'Mahallende gördüğün üç meslek sahibini ve ne iş yaptıklarını defterine yaz.'],
    ['Doğayı koruyoruz', 'Evde geri dönüşüme gönderebileceğin üç atığı bul ve neden geri dönüştürülmesi gerektiğini anlat.']],
  'Fen Bilimleri': [['Deney raporu', 'Derste yaptığımız deneyi evde sadeleştirerek tekrar et. Gözlemlerini tabloya yaz ve bir sonuç cümlesi ekle.'],
    ['Konu özeti ve kavram haritası', 'Bu haftaki üniteyi bir sayfada kavram haritası olarak özetle; en az 8 kavram ve bağlantı sözcüğü kullan.'],
    ['Test çözümü', 'Çalışma kitabındaki testi zaman tutarak çöz. Süreni ve yanlış yaptığın soruların numaralarını yaz.'], ['Günlük hayatta fen', 'Evde bulduğun üç araç gerecin hangi fen konusuyla ilgili olduğunu açıkla.']],
  'Sosyal Bilgiler': [['Aile tarihi röportajı', 'Büyüklerinden biriyle çocukluğundaki bir okul günü hakkında konuş. Öğrendiklerini 6-8 cümleyle yaz.'],
    ['Harita çalışması', 'Atlasından konuyla ilgili haritayı çiz; komşu ülkeleri ve çevre denizleri etiketle.'], ['Ders kitabı soruları', '"Değerlendirelim" sorularını tam cümleyle yanıtla.']],
  [INKILAP]: [['Kronoloji çalışması', 'Derste işlediğimiz olayları tarih sırasına göre bir zaman çizelgesinde göster.'], ['Önemli kişiler kartı', 'Konuyla ilgili üç önemli kişi için kısa tanıtım kartı hazırla.'],
    ['Kaynak okuma', 'Verilen metni oku, olayın nedenlerini ve sonuçlarını iki sütunlu tabloya yaz.']],
  'İngilizce': [['Vocabulary practice', 'Learn the new words of the unit. Write each word in a sentence of your own and be ready for a short quiz.'], ['Workbook pages', 'Complete the workbook exercises for this unit and read the dialogue aloud twice at home.'],
    ['My daily routine', 'Write 8 sentences about your daily routine using "first, then, after that".']],
  'Görsel Sanatlar': [['Sonbahar teması resim', 'Sonbaharı anlatan bir resim yap. Sulu boya veya pastel kullanabilirsin; bir sonraki derse A4 kâğıtta getir.'], ['Malzeme hazırlığı', 'Gelecek haftaki kolaj çalışması için eski dergi kesikleri, makas ve yapıştırıcı getir.']],
  'Müzik': [['Şarkı sözü ezberi', 'Derste öğrendiğimiz şarkının ilk iki kıtasını ezberle. Gelecek derste tek tek söyleyeceğiz.'], ['Dinleme çalışması', 'Sevdiğin bir parçayı dinle; hangi çalgıları duyduğunu ve sende bıraktığı duyguyu 3-4 cümleyle yaz.']],
  'Bilişim': [['Güvenli internet kuralları', 'Güvenli internet kullanımı için kendi 5 maddelik kural listeni hazırla.'], ['Klavye alıştırması', 'Haftada üç gün, günde 10 dakika on parmak klavye alıştırması yap; ilerlemeni not et.']],
  'Beden Eğitimi': [['Haftalık hareket takvimi', 'Bu hafta her gün en az 30 dakika hareket et. Ne yaptığını ve süresini tabloya işle.'], ['Spor kıyafeti hatırlatması', 'Gelecek ders için spor kıyafetini ve yedek çorabını unutma.']],
  'Din Kültürü': [['Değerler çalışması', 'Dürüstlük ve yardımlaşma konusunda yaşadığın ya da tanık olduğun bir örneği 5-6 cümleyle yaz.'], ['Ders kitabı etkinlikleri', 'Ders kitabındaki etkinlikleri tamamla; boş bıraktığın etkinlik olmasın.']],
  'Edebiyat': [['Metin çözümlemesi', 'Derste okuduğumuz metnin ana düşüncesini, yardımcı düşüncelerini ve anlatım özelliklerini defterine yaz.'], ['Kitap tahlili', 'Okuduğun romanın olay örgüsünü, kahramanlarını ve zamanını bir sayfada özetle.'], ['Kompozisyon: Gençlik ve gelecek', '350 kelimelik bir yazı yaz; giriş, gelişme ve sonuç bölümlerine dikkat et.']],
  'Fizik': [['Problem çözümü: Hareket', 'Çalışma kâğıdındaki hareket problemlerini çöz; birimleri yazmayı unutma.'], ['Konu tekrarı ve formül kartı', 'Ünitenin formüllerini ve birimlerini tek sayfalık bir kartta topla.']],
  'Kimya': [['Periyodik tablo çalışması', 'Verilen elementlerin atom numarası, grup ve periyodunu tabloya işle.'], ['Tepkime denkleştirme', 'Çalışma kâğıdındaki tepkimeleri denkleştir.']],
  'Biyoloji': [['Hücre şeması', 'Hücre organellerini gösteren etiketli bir şema çiz ve görevlerini yaz.'], ['Konu özeti', 'Ünitenin kavram haritasını çıkar.']],
  'Tarih': [['Olay-neden-sonuç tablosu', 'İşlediğimiz dönemin üç önemli olayını neden ve sonuçlarıyla tabloya yaz.'], ['Kaynak analizi', 'Verilen belge metnini oku; yazarının amacını ve bakış açısını yorumla.']],
  'Coğrafya': [['Harita çalışması', 'Konuyla ilgili haritayı çiz ve iklim bölgelerini renklendir.'], ['Grafik yorumlama', 'Verilen sıcaklık ve yağış grafiğini yorumla; iki çıkarım yaz.']],
  'Felsefe': [['Düşünce günlüğü', 'Derste tartıştığımız soruyu seç; kendi görüşünü gerekçelendirerek yaz.']],
  'Teknoloji ve Tasarım': [['Tasarım taslağı', 'Verilen soruna çözüm olacak bir ürünün taslağını çiz ve malzemelerini listele.']],
};
const GENEL_ODEV = [['Konu tekrarı', 'Derste işlediğimiz konuyu defterinden tekrar et, anlamadığın yerleri işaretle.'], ['Çalışma kâğıdı', 'Çalışma kâğıdını tamamla ve bir sonraki derse getir.']];

const png = (w, h, r, g, b) => {
  const satir = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) { const o = y * (w * 3 + 1); for (let x = 0; x < w; x++) { const t = (x + y) / (w + h); satir[o + 1 + x * 3] = Math.round(r + (255 - r) * t * 0.6); satir[o + 2 + x * 3] = Math.round(g + (255 - g) * t * 0.6); satir[o + 3 + x * 3] = Math.round(b + (255 - b) * t * 0.6); } }
  const parca = (tur, veri) => { const u = Buffer.alloc(4); u.writeUInt32BE(veri.length); const c = Buffer.alloc(4); c.writeUInt32BE(crc32(Buffer.concat([Buffer.from(tur), veri])) >>> 0); return Buffer.concat([u, Buffer.from(tur), veri, c]); };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), parca('IHDR', ihdr), parca('IDAT', deflateSync(satir)), parca('IEND', Buffer.alloc(0))]);
};
const resimler = [[90, 140, 200], [200, 150, 90], [110, 170, 120], [180, 120, 160]].map(c => png(120, 90, ...c));
const OGRENCI_NOTLARI = ['Son soruyu çözemedim.', 'Defterime yazdım.', 'Bir kısmını tamamlayamadım, yardım alabilir miyim?', 'Dün hastaydım, yarın teslim ederim.'];
const OGRETMEN_NOTLARI = ['Düzenli, tebrikler.', 'Güzel bir çalışma olmuş.', 'Emeğin görülüyor, böyle devam.'];
const DUZELTME_NOTLARI = ['Üçüncü soruda işlem basamaklarını yazmayı unutmuşsun, düzeltip tekrar işaretle.', 'Cümlelerin sonuna noktalama işareti koymayı unutma, düzelt.', 'Tablodaki bir sütun eksik, tamamlayıp tekrar işaretle.'];
const SORULAR = ['Hocam ikinci soruda sonucu nasıl yazmalıyım?', 'Bu ödevde kaynak kitaptan mı çözeceğiz, çalışma kâğıdından mı?', 'Hocam örnek bir çözüm gösterebilir misiniz?', 'Teslim için fotoğraf yeterli mi?'];
const CEVAPLAR = ['Sonucu hem sayı hem birim olarak yaz; örnek çözüm derste yapıldı, defterine bakabilirsin.', 'Kaynak kitaptan çözün, çalışma kâğıdı bir sonraki derste dağıtılacak.', 'Yarın derste ilk beş dakikada örnek bir çözüm göstereceğim.', 'Evet, okunaklı bir fotoğraf yeterli.'];

// ---------- Okul günleri: yoklama, işlenen konu, ödev (yeni okullar okul başından, mevcutlar son kayıttan sonra) ----------
const sayim = { yoklama: 0, konu: 0, odev: 0, odevDurum: 0 };
function etkinlik(o) {
  const sonKayit = bir(`SELECT MAX(y.date) d FROM yoklama y JOIN classes c ON c.id = y.class_id WHERE c.branch_id = ?`, o.id)?.d;
  const basla = sonKayit ? kaydir(sonKayit, 1) : OKUL_BASI;
  const varOlan = new Set(tum(`SELECT y.class_id || '|' || y.date || '|' || y.period k FROM yoklama y JOIN classes c ON c.id = y.class_id WHERE c.branch_id = ? AND y.date >= ?`, o.id, basla).map(r => r.k));
  const gunler = [];
  for (let t = basla; t <= bugun; t = kaydir(t, 1)) if (gunNo(t) >= 1 && gunNo(t) <= 5 && !TATILLER.has(t)) gunler.push(t);
  if (!gunler.length) return;
  const programGunu = new Map();
  for (const r of o.programSatirlari) { if (!programGunu.has(r.gun)) programGunu.set(r.gun, []); programGunu.get(r.gun).push(r); }
  for (const g of programGunu.values()) g.sort((x, y) => x.saat - y.saat || x.sinif.id - y.sinif.id);
  const gunDurumu = new Map();
  const dersler = new Map(); // atama id -> dersler
  for (const t of gunler) {
    const sonGun = t >= kaydir(bugun, -4);
    for (const r of programGunu.get(gunNo(t)) || []) {
      if (varOlan.has(`${r.sinif.id}|${t}|${r.saat}`)) continue;
      const [bas, bit] = DERS_ZAMANLARI[r.saat - 1];
      const bitis = zaman(t, bit);
      if (bitis > simdi - 5 * 60000) continue; // henüz bitmemiş ders
      const iptal = rnd() < 0.015;
      const bitti = !iptal && !(sonGun && rnd() < 0.07);
      const kv = bitti ? sonrakiKonu(r.atama) : null;
      const yid = ins(`INSERT INTO yoklama (class_id, date, period, assignment_id, teacher_membership_id, created_at, updated_at, topic, kazanim, completed_at, cancelled) VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
        r.sinif.id, t, r.saat, r.atama.id, r.atama.ogr.mid, zaman(t, bas) + 3 * 60000, bitis, kv?.konu ?? null, kv?.kazanim ?? null, bitti ? bitis + 2 * 60000 : iptal ? bitis : null, iptal ? 1 : 0);
      sayim.yoklama++;
      if (kv) { calis('INSERT INTO konular (assignment_id, date, title, note, created_at, yoklama_id, kazanim) VALUES (?,?,?,?,?,?,?)', r.atama.id, t, kv.konu, kv.kazanim ? 'Kazanım: ' + kv.kazanim : null, bitis, yid, kv.kazanim); sayim.konu++; }
      if (!dersler.has(r.atama.id)) dersler.set(r.atama.id, []);
      dersler.get(r.atama.id).push({ tarih: t, yid, bitti, kazanim: kv?.kazanim ?? null, zaman: bitis, at: r.atama });
      if (iptal) continue;
      const ilkSaat = Math.min(...(programGunu.get(gunNo(t)) || []).filter(z => z.sinif === r.sinif).map(z => z.saat));
      for (const ogr of r.sinif.ogrenciler) {
        const anahtar = `${ogr.mid}-${t}`;
        if (!gunDurumu.has(anahtar)) {
          const x = rnd();
          gunDurumu.set(anahtar, x < ogr.egilim ? { durum: 'gelmedi', ogleden: rnd() < 0.2 } : x < ogr.egilim + 0.012 ? { durum: 'gec' } : x < ogr.egilim + 0.03 ? { durum: 'izinli' } : { durum: 'geldi' });
        }
        const d = gunDurumu.get(anahtar);
        const durum = d.durum === 'gec' ? (r.saat === ilkSaat ? 'gec' : 'geldi') : d.ogleden && r.saat <= 3 ? 'geldi' : d.durum;
        calis('INSERT INTO yoklama_kayit (yoklama_id, student_membership_id, status) VALUES (?,?,?)', yid, ogr.mid, durum);
      }
    }
  }
  // Ödevler
  if (o.tur === 'Anaokulu') return;
  const sonrakiDers = (a, t) => {
    const gunleri = new Set(o.programSatirlari.filter(r => r.atama === a).map(r => r.gun));
    for (let i = 1; i <= 14; i++) { const x = kaydir(t, i); if (gunleri.has(gunNo(x)) && !TATILLER.has(x)) return x; }
    return kaydir(t, 7);
  };
  const odevler = [];
  const sayac = new Map();
  for (const [aId, liste] of dersler) {
    const at = liste[0].at;
    if (ODEVSIZ.has(at.ders)) continue;
    const olasilik = at.saat >= 4 ? 0.26 : at.saat === 3 ? 0.3 : 0.28;
    liste.forEach((d, i) => {
      if (!d.bitti || rnd() > olasilik) return;
      const son = liste[i + 1] ? liste[i + 1].tarih : sonrakiDers(at, d.tarih);
      const havuz = ODEVLER[at.ders] ?? GENEL_ODEV;
      const k = (sayac.get(aId) ?? tum('SELECT COUNT(*) n FROM odevler WHERE assignment_id = ?', aId)[0].n); sayac.set(aId, k + 1);
      const [baslik, not] = havuz[k % havuz.length];
      const id = ins('INSERT INTO odevler (assignment_id, title, note, due_date, created_at, kazanim, yoklama_id) VALUES (?,?,?,?,?,?,?)', aId, baslik, not, son, d.zaman + 5 * 60000, d.kazanim, d.yid);
      odevler.push({ id, at, son, zaman: d.zaman }); sayim.odev++;
    });
  }
  const soruCevap = [];
  for (const od of odevler) {
    for (const ogr of od.at.sinif.ogrenciler) {
      const eski = od.son < kaydir(bugun, -6), yakin = od.son < kaydir(bugun, -1), gelecek = od.son >= bugun;
      const x = rnd();
      let durum = null;
      if (gelecek) { if (x < 0.2 * ogr.caliskan) durum = 'yapildi'; }
      else if (x < ogr.caliskan * 0.94) durum = eski ? (rnd() < 0.93 ? 'dogrulandi' : 'duzeltme') : yakin ? (rnd() < 0.55 ? 'dogrulandi' : 'yapildi') : 'yapildi';
      else if (x < ogr.caliskan * 0.94 + 0.06) durum = 'yapilamadi';
      if (!durum) continue;
      const isaret = zaman(od.son, '20:00') - Math.floor(rnd() * 20) * 36e5 - (gelecek ? 24 * 36e5 : 0);
      const isaretZ = Math.min(isaret, simdi - 36e5);
      const yapildi = durum === 'dogrulandi' || durum === 'yapildi' || durum === 'duzeltme';
      calis('INSERT INTO odev_durumlari (odev_id, student_membership_id, durum, ogrenci_notu, ogretmen_notu, isaret_zamani, dogrulama_zamani, guncelleme) VALUES (?,?,?,?,?,?,?,?)', od.id, ogr.mid, durum,
        durum === 'yapilamadi' ? sec(OGRENCI_NOTLARI) : durum === 'yapildi' && rnd() < 0.2 ? 'Defterime yazdım.' : null,
        durum === 'duzeltme' ? sec(DUZELTME_NOTLARI) : durum === 'dogrulandi' && rnd() < 0.3 ? sec(OGRETMEN_NOTLARI) : null,
        isaretZ, durum === 'dogrulandi' ? Math.min(zaman(kaydir(od.son, 1), '10:30') + Math.floor(rnd() * 4) * 36e5, simdi - 36e5) : null, isaretZ);
      sayim.odevDurum++;
      if (yapildi && rnd() < 0.18) { const p = sec(resimler); calis("INSERT INTO odev_dosyalari (odev_id, student_membership_id, mesaj_id, amac, mime, boyut, veri, created_at) VALUES (?,?,NULL,'teslim','image/png',?,?,?)", od.id, ogr.mid, p.length, p, isaretZ); }
      if (!eski && rnd() < 0.07) soruCevap.push({ od, ogr });
    }
  }
  for (const { od, ogr } of soruCevap) {
    const sor = ins('INSERT INTO odev_mesajlari (odev_id, student_membership_id, yazan_membership_id, yazan_rol, metin, okundu, created_at) VALUES (?,?,?,?,?,?,?)', od.id, ogr.mid, ogr.mid, 'ogrenci', sec(SORULAR), 1, od.zaman + 24 * 36e5);
    if (rnd() < 0.7) calis('INSERT INTO odev_mesajlari (odev_id, student_membership_id, yazan_membership_id, yazan_rol, metin, okundu, created_at) VALUES (?,?,?,?,?,?,?)', od.id, ogr.mid, od.at.ogr.mid, 'ogretmen', sec(CEVAPLAR), rnd() < 0.5 ? 1 : 0, od.zaman + 30 * 36e5);
    if (rnd() < 0.4) { const p = sec(resimler); calis("INSERT INTO odev_dosyalari (odev_id, student_membership_id, mesaj_id, amac, mime, boyut, veri, created_at) VALUES (?,?,?,'soru','image/png',?,?,?)", od.id, ogr.mid, sor, p.length, p, od.zaman + 24 * 36e5); }
  }
}

// ---------- Etütler ----------
const ETUT_KONULARI = ['Soru çözümü', 'Konu tekrarı', 'Eksik konular', 'Sınav hazırlık', 'Problemler', 'Kazanım pekiştirme'];
function etutler(o) {
  if (o.tur === 'Anaokulu') return 0;
  let n = 0;
  const adaylar = o.ogretmenler.filter(t => t.dersler[0] !== 'Beden Eğitimi' && t.dersler[0] !== 'Müzik' && t.dersler[0] !== 'Görsel Sanatlar' && t.dersler[0] !== 'Rehberlik').slice(0, 12);
  for (const t of adaylar) {
    const var_ = bir('SELECT COUNT(*) n FROM etutler WHERE teacher_membership_id = ?', t.mid).n;
    if (var_ >= 3) continue;
    const atamalar = o.siniflar.flatMap(s => Object.values(s.atama)).filter(a => a.ogr.mid === t.mid);
    if (!atamalar.length) continue;
    const ders = atamalar[0].ders;
    for (const pl of [-20, -13, -7, 5].slice(var_)) {
      const gecmis = pl < 0;
      let tarih = kaydir(bugun, pl + Math.floor(rnd() * 5) - 2);
      while (gunNo(tarih) === 0 || gunNo(tarih) === 6 || (gecmis ? tarih >= bugun : tarih <= bugun)) tarih = kaydir(tarih, gecmis ? -1 : 1);
      if (tarih < OKUL_BASI) continue;
      const id = ins(`INSERT INTO etutler (teacher_membership_id, course_id, topic, date, start_time, duration_min, place, note, status, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)`,
        t.mid, dersId(ders), sec(ETUT_KONULARI), tarih, sec(o.ilk ? ['14:40', '15:30'] : ['15:30', '16:20']), 40, sec(['Sınıfta', 'Kütüphane', 'Etüt odası']), null, 'planli', zaman(kaydir(tarih, -4), '10:00'));
      for (const ogr of karistir(sec(atamalar).sinif.ogrenciler).slice(0, 3 + Math.floor(rnd() * 4))) {
        const yanit = gecmis ? (rnd() < 0.85 ? 'gelecek' : 'gelmeyecek') : sec(['gelecek', 'gelecek', 'bekliyor', 'gelmeyecek']);
        const devam = gecmis ? (yanit === 'gelecek' ? (rnd() < 0.9 ? 'geldi' : 'gelmedi') : sec(['gelmedi', 'izinli'])) : null;
        calis('INSERT INTO etut_katilimcilar (etut_id, student_membership_id, parent_response, responded_at, attendance) VALUES (?,?,?,?,?)', id, ogr.mid, yanit, yanit === 'bekliyor' ? null : zaman(kaydir(tarih, -2), '19:00'), devam);
      }
      n++;
    }
  }
  return n;
}

// ---------- Sınavlar ----------
const SINAV_DERSLERI = {
  3: [['Türkçe', 10], ['Matematik', 10], ['Hayat Bilgisi', 10], ['Fen Bilimleri', 10]],
  4: [['Türkçe', 15], ['Matematik', 15], ['Fen Bilimleri', 10], ['Sosyal Bilgiler', 10]],
  5: [['Türkçe', 15], ['Matematik', 15], ['Fen Bilimleri', 15], ['Sosyal Bilgiler', 10], ['İngilizce', 10]],
  6: [['Türkçe', 15], ['Matematik', 15], ['Fen Bilimleri', 15], ['Sosyal Bilgiler', 10], ['İngilizce', 10]],
  7: [['Türkçe', 15], ['Matematik', 15], ['Fen Bilimleri', 15], ['Sosyal Bilgiler', 10], ['İngilizce', 10]],
  8: [['Türkçe', 20], ['Matematik', 20], ['Fen Bilimleri', 20], [INKILAP, 10], ['Din Kültürü', 10], ['İngilizce', 10]],
  9: [['Edebiyat', 15], ['Matematik', 15], ['Fizik', 10], ['Kimya', 10], ['Biyoloji', 10], ['Tarih', 10], ['Coğrafya', 10]],
  10: [['Edebiyat', 15], ['Matematik', 15], ['Fizik', 10], ['Kimya', 10], ['Biyoloji', 10], ['Tarih', 10], ['Coğrafya', 10], ['Felsefe', 10]],
  11: [['Edebiyat', 20], ['Matematik', 20], ['Fizik', 15], ['Kimya', 15], ['Biyoloji', 15], ['Tarih', 10], ['Coğrafya', 10], ['Felsefe', 10]],
  12: [['Edebiyat', 20], ['Matematik', 20], ['Fizik', 15], ['Kimya', 15], ['Biyoloji', 15], ['Tarih', 10], ['Coğrafya', 10], ['Felsefe', 10]],
};
const DENEMELER = [
  { ad: 'Açılış Sınavı', tarih: haftaIci(kaydir(OKUL_BASI, 7)), yayin: 0, kat: 0, amac: 'acilis', cevapli: true },
  { ad: '1. Deneme Sınavı', tarih: haftaIci(kaydir(bugun, -24)), yayin: 1, kat: 3, cevapli: true },
  { ad: '2. Deneme Sınavı', tarih: haftaIci(kaydir(bugun, -14)), yayin: 1, kat: 3, cevapli: true },
  { ad: '3. Deneme Sınavı', tarih: haftaIci(kaydir(bugun, -4)), yayin: 0, kat: 3, cevapli: true },
  { ad: '4. Deneme Sınavı', tarih: haftaIci(kaydir(bugun, 7)), yayin: 0, kat: 3, cevapli: false, hazirlik: true },
];
const SIKLAR = 'ABCDE';
const yetenekDers = (ogr, ders) => (ogr.yet.ders[ders] ??= gauss() * 0.4);
const ortakSinav = new Map();
const ortak = duzey => {
  if (ortakSinav.has(duzey)) return ortakSinav.get(duzey);
  const sonuc = DENEMELER.map((dn, dnNo) => SINAV_DERSLERI[duzey].map(([ders, n]) => {
    const tam = Array.from({ length: n }, () => sec(SIKLAR)).join('');
    const kaz = dersKazanimlari(ders, duzey);
    const kazanimlar = [];
    if (kaz.length) { let k = (dnNo * 7) % kaz.length; for (let i = 1; i <= n; i++) { if (!(i > 1 && rnd() < 0.35)) k = (k + 1) % kaz.length; kazanimlar.push(kazMetni(kaz[k])); } }
    return { ders, n, tam, zorluk: Array.from({ length: n }, () => gauss() * 0.9 + 0.2), kazanimlar, iptal: dnNo === 1 && ders === 'Matematik' ? [Math.min(17, n)] : [] };
  }));
  ortakSinav.set(duzey, sonuc);
  return sonuc;
};
const YAZILI_GUN = { 'Türkçe': -20, 'Matematik': -18, 'Hayat Bilgisi': -13, 'Fen Bilimleri': -13, 'Sosyal Bilgiler': -11, [INKILAP]: -11, 'İngilizce': -11, 'Din Kültürü': -12, 'Edebiyat': -19, 'Fizik': -17, 'Kimya': -16, 'Biyoloji': -15, 'Tarih': -14, 'Coğrafya': -12, 'Felsefe': -10 };
const PERFORMANS = { 'Beden Eğitimi': -10, 'Görsel Sanatlar': -12, 'Müzik': -14, 'Bilişim': -15, 'Teknoloji ve Tasarım': -9 };
const KISA = { [INKILAP]: 'İnkılap Tarihi' };

function sinavlar(o) {
  let sayi = 0;
  const yon = o.mudurMid;
  for (const duzey of [...o.duzeyler].filter(d => d >= 1).sort((a, b) => a - b)) {
    const siniflar = o.siniflar.filter(s => s.duzey === duzey);
    const ogrenciler = siniflar.flatMap(s => s.ogrenciler);
    const dersOgretmeni = ders => siniflar.map(s => s.atama[ders]?.ogr).find(Boolean) ?? o.ogretmenler[0];
    const siniflarSql = siniflar.map(s => s.id).join(',');
    const mevcutAd = new Set(tum(`SELECT DISTINCT sn.name || '|' || sn.tur n FROM sinavlar sn JOIN sinav_siniflar ss ON ss.sinav_id = sn.id WHERE ss.class_id IN (${siniflarSql}) AND sn.duzey = ?`, duzey).map(r => r.n));
    const mevcutYazili = new Set(tum(`SELECT sd.ders FROM sinavlar sn JOIN sinav_siniflar ss ON ss.sinav_id = sn.id JOIN sinav_dersler sd ON sd.sinav_id = sn.id WHERE ss.class_id IN (${siniflarSql}) AND sn.duzey = ? AND sn.tur = 'yazili'`, duzey).map(r => r.ders));
    if (SINAV_DERSLERI[duzey]) {
      const dersListe = SINAV_DERSLERI[duzey].filter(([d]) => PROGRAM[duzey][d]);
      const ort = ortak(duzey);
      DENEMELER.forEach((dn, dnNo) => {
        if (mevcutAd.has(`${dn.ad}|test`) || mevcutAd.has(`${duzey}. Sınıf ${dn.ad}|test`)) return;
        const sid = ins(`INSERT INTO sinavlar (name, date, teacher_membership_id, yanlis_kat, created_at, yayin, tur, duzey, durum, amac) VALUES (?,?,?,?,?,?,'test',?,'aktif',?)`,
          dn.ad, dn.tarih, yon, dn.kat, zaman(kaydir(dn.tarih, -12), '10:00'), dn.yayin, duzey, dn.amac || 'deneme');
        for (const s of siniflar) calis('INSERT INTO sinav_siniflar (sinav_id, class_id) VALUES (?,?)', sid, s.id);
        sayi++;
        dersListe.forEach(([ders, n]) => {
          const dersNo = SINAV_DERSLERI[duzey].findIndex(([d]) => d === ders);
          const c = ort[dnNo][dersNo];
          const tamam = !dn.hazirlik || dersNo === 0, yarim = dn.hazirlik && dersNo === 1;
          const anahtar = tamam ? c.tam : yarim ? c.tam.slice(0, Math.ceil(n * 0.6)).padEnd(n, '?') : '?'.repeat(n);
          const hoca = dersOgretmeni(ders);
          const dId = ins('INSERT INTO sinav_dersler (sinav_id, ders, soru_sayisi, anahtar, iptal, onay, onaylayan, onay_tarih) VALUES (?,?,?,?,?,?,?,?)', sid, ders, n, anahtar, JSON.stringify(c.iptal), tamam ? 1 : 0, tamam ? hoca.mid : null, tamam ? zaman(kaydir(dn.tarih, -3), '16:00') : null);
          if (dn.cevapli) for (const ogr of ogrenciler) {
            if (rnd() < 0.04) continue;
            const guc = ogr.yet.genel + yetenekDers(ogr, ders) + dnNo * 0.15;
            let cv = '';
            for (let i = 0; i < n; i++) {
              const p = 1 / (1 + Math.exp(-(guc - c.zorluk[i] + 0.9) * 1.3));
              const x = rnd();
              cv += x < p ? c.tam[i] : x < p + (1 - p) * 0.25 ? '-' : sec(SIKLAR.replace(c.tam[i], '').split(''));
            }
            calis('INSERT INTO sinav_cevaplar (sinav_ders_id, student_membership_id, cevaplar) VALUES (?,?,?)', dId, ogr.mid, cv);
          }
          const girilecek = tamam ? n : yarim ? Math.ceil(n * 0.45) : 0;
          for (let i = 1; i <= Math.min(girilecek, c.kazanimlar.length); i++) calis('INSERT INTO sinav_kazanim (sinav_ders_id, soru_no, kazanim, guncelleyen, tarih) VALUES (?,?,?,?,?)', dId, i, c.kazanimlar[i - 1], hoca.mid, zaman(kaydir(dn.tarih, -5), '15:00'));
        });
      });
    }
    // Yazılı / performans notları (puanları dersin öğretmeni girer)
    Object.keys(PROGRAM[duzey]).filter(d => YAZILI_GUN[d] !== undefined || PERFORMANS[d] !== undefined).forEach((ders, yNo) => {
      if (mevcutYazili.has(ders)) return;
      const perf = PERFORMANS[ders] !== undefined;
      const tarih = haftaIci(kaydir(bugun, perf ? PERFORMANS[ders] : YAZILI_GUN[ders]));
      const kisa = KISA[ders] ?? ders;
      const sid = ins(`INSERT INTO sinavlar (name, date, teacher_membership_id, yanlis_kat, created_at, yayin, tur, duzey, durum, amac) VALUES (?,?,?,0,?,?,'yazili',?,'aktif','deneme')`,
        `1. Dönem ${perf ? kisa + ' Performans Notu' : '1. ' + kisa + ' Yazılısı'}`, tarih, yon, zaman(kaydir(tarih, -12), '10:00'), tarih <= kaydir(bugun, -8) ? 1 : 0, duzey);
      for (const s of siniflar) calis('INSERT INTO sinav_siniflar (sinav_id, class_id) VALUES (?,?)', sid, s.id);
      const dId = ins("INSERT INTO sinav_dersler (sinav_id, ders, soru_sayisi, anahtar, iptal, onay, onaylayan, onay_tarih) VALUES (?,?,0,'','[]',1,?,?)", sid, ders, dersOgretmeni(ders).mid, zaman(tarih, '12:00'));
      const kaz = dersKazanimlari(ders, duzey);
      for (let i = 0; i < Math.min(3, kaz.length); i++) calis('INSERT INTO sinav_genel_kazanim (sinav_id, sira, kazanim) VALUES (?,?,?)', sid, i + 1, kazMetni(kaz[(yNo * 3 + i) % kaz.length]));
      for (const ogr of ogrenciler) {
        if (rnd() < 0.04) continue;
        calis('INSERT INTO sinav_puanlar (sinav_ders_id, student_membership_id, puan) VALUES (?,?,?)', dId, ogr.mid, Math.round(sinirla(68 + ogr.yet.genel * 14 + yetenekDers(ogr, ders) * 8 + gauss() * 6, 10, 100)));
      }
      sayi++;
    });
  }
  return sayi;
}

// ---------- Kulüpler (yeni okullar) ----------
const KULUP_TANIM = {
  'Robotik ve Kodlama': { tema: 'Bilim ve teknoloji', aciklama: 'Her hafta bir devre ya da robot projesi tasarlıyor, kodluyor ve deniyoruz.', ders: ['Bilişim', 'Matematik', 'Fizik'], kont: 14 },
  'Bilim ve Deney': { tema: 'Fen', aciklama: 'Evde bulunan malzemelerle haftalık deneyler yapıp sonuçları tartışıyoruz.', ders: ['Fen Bilimleri', 'Fizik', 'Kimya', 'Sınıf Öğretmenliği'], kont: 12 },
  'Satranç ve Zeka Oyunları': { tema: 'Strateji', aciklama: 'Açılış stratejileri, bulmacalar ve okul içi turnuvalar.', ders: ['Matematik', 'Sınıf Öğretmenliği'], kont: 6 },
  'Müzik ve Koro': { tema: 'Sanat', aciklama: 'Koro çalışması ve yıl sonu konseri için repertuvar hazırlığı.', ders: ['Görsel Sanatlar', 'Müzik'], kont: 16 },
  'Drama ve Tiyatro': { tema: 'Dil ve sahne', aciklama: 'Kısa oyunlar ve doğaçlama çalışmaları.', ders: ['İngilizce', 'Türkçe', 'Edebiyat', 'Sınıf Öğretmenliği'], kont: 12 },
  'Münazara ve Hitabet': { tema: 'Dil ve sahne', aciklama: 'Münazara kuralları, etkili konuşma ve okullar arası turnuvalara hazırlık.', ders: ['Edebiyat', 'Tarih', 'Felsefe'], kont: 12 },
  'Edebiyat ve Yazarlık': { tema: 'Edebiyat', aciklama: 'Okuma halkaları ve okul dergisi için yazı atölyesi.', ders: ['Edebiyat', 'Türkçe'], kont: 14 },
  'Fotoğrafçılık': { tema: 'Sanat', aciklama: 'Kadraj, ışık ve fotoğraf yürüyüşleriyle görsel anlatım.', ders: ['Görsel Sanatlar', 'Bilişim'], kont: 10 },
};
const KULUP_SETLERI = { 'İlkokul': ['Robotik ve Kodlama', 'Bilim ve Deney', 'Satranç ve Zeka Oyunları', 'Müzik ve Koro', 'Drama ve Tiyatro'], 'Ortaokul': ['Robotik ve Kodlama', 'Bilim ve Deney', 'Satranç ve Zeka Oyunları', 'Müzik ve Koro', 'Drama ve Tiyatro'],
  'Lise': ['Robotik ve Kodlama', 'Münazara ve Hitabet', 'Edebiyat ve Yazarlık', 'Fotoğrafçılık', 'Satranç ve Zeka Oyunları'] };
const CALISMALAR = {
  'Resim ve El Sanatları': [['proje', 'Sonbahar yaprakları baskısı', 'Yapraklarla baskı tekniğini denedik.'], ['proje', 'Kolaj çalışması', 'Dergi kesikleriyle hayvan kolajı yaptık.']],
  'Satranç ve Zeka Oyunları': [['diger', 'Açılış ilkeleri', 'Merkezi ele geçirme ve taş gelişimi.'], ['diger', 'Mat kalıpları', 'Vezir ve kale ile mat kalıplarını çalıştık.'], ['diger', 'Mini turnuva', 'Kendi aramızda turnuva oynadık.'], ['diger', 'Bulmaca çözümü', 'Tek hamlede mat bulmacaları çözdük.']],
  'Müzik ve Koro': [['diger', 'Ses ısınma çalışması', 'Nefes ve ses ısınma egzersizleri.'], ['diger', 'Şarkı çalışması', 'Yeni şarkının ilk iki kıtasını öğrendik.'], ['sunum', 'Konser provası', 'İlk iki parçanın provası.'], ['diger', 'Ritim çalışması', 'Vurmalı çalgılarla ritim kalıpları çalıştık.']],
  'Bilim ve Deney': [['deney', 'Yanardağ deneyi', 'Karbonat ve sirke ile yanardağ yaptık.'], ['deney', 'Yoğunluk kuleleri', 'Farklı sıvılarla yoğunluk kulesi kurduk.'], ['deney', 'Mıknatıs ve alan', 'Demir tozuyla manyetik alan çizgilerini gözledik.'], ['sunum', 'Bilim fuarı hazırlığı', 'Standlar için proje seçimi yapıldı.']],
  'Robotik ve Kodlama': [['deney', 'Basit elektrik devresi', 'Pil, ampul ve anahtarla devre kurduk.'], ['proje', 'Engelden kaçan robot', 'Sensör bağlantısını yaptık, kodu yazmaya başladık.'], ['proje', 'Engelden kaçan robot: test', 'Robotları pistte denedik.'], ['proje', 'Blok kodlama oyunu', 'Blok tabanlı kodlamayla küçük bir oyun yazdık.']],
  'Drama ve Tiyatro': [['sunum', 'Kısa skeç', 'Rol dağılımı yapıldı ve ilk okuma yapıldı.'], ['diger', 'Doğaçlama oyunları', 'Doğaçlama oyunlarıyla ısındık.'], ['sunum', 'Skeç provası', 'Sahne yerleşimini ve replikleri çalıştık.'], ['sunum', 'Sınıf içi gösteri', 'Skeci arkadaşlarımıza sahneledik.']],
  'Münazara ve Hitabet': [['diger', 'Münazara kuralları', 'Tez, antitez ve süre kullanımı üzerine çalıştık.'], ['sunum', 'Deneme münazarası', 'İlk deneme münazarasını yaptık.'], ['diger', 'Etkili konuşma', 'Beden dili ve ses tonu çalışması.'], ['sunum', 'Turnuva hazırlığı', 'Okullar arası turnuva için takımlar belirlendi.']],
  'Edebiyat ve Yazarlık': [['diger', 'Okuma halkası', 'Seçilen romanın ilk bölümlerini tartıştık.'], ['proje', 'Okul dergisi yazıları', 'Dergi için yazı konuları paylaşıldı.'], ['diger', 'Yaratıcı yazarlık', 'Verilen ilk cümleden hikâye yazdık.'], ['sunum', 'Şiir dinletisi', 'Sevdiğimiz şiirleri okuduk.']],
  'Fotoğrafçılık': [['diger', 'Kadraj ve kompozisyon', 'Üçler kuralı ve kadraj denemeleri.'], ['gezi', 'Fotoğraf yürüyüşü', 'Okul çevresinde yürüyüş yaptık.'], ['proje', 'Portre çalışması', 'Doğal ışıkta portre çektik.'], ['sunum', 'Mini sergi', 'En iyi karelerimizi koridorda sergiledik.']],
};
function kulupler(o) {
  const set = KULUP_SETLERI[o.tur];
  if (!set || tum('SELECT 1 x FROM kulupler WHERE branch_id = ?', o.id).length) return 0;
  const seviyeler = [...o.duzeyler].filter(d => d >= 1).sort((a, b) => a - b);
  const carsambalar = [];
  for (let t = kaydir(OKUL_BASI, 16); t <= bugun; t = kaydir(t, 1)) if (gunNo(t) === KULUP_GUN && !TATILLER.has(t)) carsambalar.push(t);
  let sonrakiCarsamba = bugun; do sonrakiCarsamba = kaydir(sonrakiCarsamba, 1); while (gunNo(sonrakiCarsamba) !== KULUP_GUN);
  const yerlesen = new Set(); const kayitlar = []; let n = 0;
  for (const ad of set) {
    const k = KULUP_TANIM[ad];
    const hocalar = o.ogretmenler.filter(t => t.dersler.some(d => k.ders.includes(d)));
    const hoca = hocalar.length ? hocalar[n % hocalar.length] : o.ogretmenler[n];
    const kont = o.tur === 'Lise' ? k.kont + 10 : k.kont + 6;
    const id = ins('INSERT INTO kulupler (branch_id, ad, tema, aciklama, kontenjan, gun, ders_saati, seviyeler, created_at) VALUES (?,?,?,?,?,?,?,?,?)', o.id, ad, k.tema, k.aciklama, kont, KULUP_GUN, o.kulupSaati, seviyeler.join(','), zaman(kaydir(OKUL_BASI, 3), '10:00'));
    calis('INSERT INTO kulup_ogretmen (kulup_id, teacher_membership_id) VALUES (?,?)', id, hoca.mid);
    const adaylar = karistir(o.ogrenciler.filter(x => !yerlesen.has(x.mid)));
    const uyeler = adaylar.slice(0, Math.min(kont - 2, Math.ceil(adaylar.length * 0.4)));
    for (const x of uyeler) {
      calis('INSERT INTO kulup_uyeler (kulup_id, student_membership_id, tarih) VALUES (?,?,?)', id, x.mid, zaman(kaydir(OKUL_BASI, 12), '12:00'));
      calis("INSERT INTO kulup_talepleri (student_membership_id, kulup_id, sira, durum, tarih) VALUES (?,?,1,'kabul',?)", x.mid, id, zaman(kaydir(OKUL_BASI, 8), '12:00'));
      yerlesen.add(x.mid);
    }
    const cal = CALISMALAR[ad];
    carsambalar.forEach((tarih, i) => {
      const [tur, baslik, aciklama] = cal[i % cal.length];
      const cid = ins('INSERT INTO kulup_calismalar (kulup_id, tarih, tur, baslik, aciklama, teacher_membership_id, created_at, tamamlandi) VALUES (?,?,?,?,?,?,?,?)', id, tarih, tur, baslik, aciklama, hoca.mid, zaman(kaydir(tarih, -6), '15:00'), zaman(tarih, '14:20'));
      uyeler.forEach((x, j) => calis('INSERT INTO kulup_katilim (calisma_id, student_membership_id, durum) VALUES (?,?,?)', cid, x.mid, (j + i) % 7 === 3 ? 'gelmedi' : (j + i) % 11 === 5 ? 'izinli' : 'geldi'));
    });
    for (const hafta of [0, 1]) { const [pt, pb, pa] = cal[(carsambalar.length + hafta) % cal.length]; calis('INSERT INTO kulup_calismalar (kulup_id, tarih, tur, baslik, aciklama, teacher_membership_id, created_at) VALUES (?,?,?,?,?,?,?)', id, kaydir(sonrakiCarsamba, hafta * 7), pt, pb, pa, hoca.mid, simdi); }
    kayitlar.push({ id, kont }); n++;
  }
  let bekleyen = 0;
  for (const x of karistir(o.ogrenciler.filter(z => !yerlesen.has(z.mid)))) {
    if (bekleyen >= 10) break;
    const liste = karistir(kayitlar).slice(0, 1 + (bekleyen % 3 === 0 ? 0 : 1));
    liste.forEach((c, i) => calis('INSERT INTO kulup_talepleri (student_membership_id, kulup_id, sira, tarih) VALUES (?,?,?,?)', x.mid, c.id, i + 1, zaman(kaydir(bugun, -3), '18:00')));
    bekleyen++;
  }
  return n;
}

// ---------- Gelişim raporu (yeni okullar) ----------
const METINLER = [
  [['Derse hazırlıklı geliyor, ödevlerini düzenli teslim ediyor. Yazılı ve denemelerde kazanımların büyük bölümünde başarılı.', 'Çalışkan ve istikrarlı; öğrendiklerini farklı bağlamlarda kullanabiliyor.'],
    ['Genel olarak yeterli düzeyde; bazı konularda küçük eksikleri var, kısa tekrar çalışmalarıyla desteklenmesi iyi olur.', 'Başarısı dönem içinde istikrarlı biçimde yükseldi, ödevlerinde ara sıra aksama oluyor.'],
    ['Bazı temel kazanımlarda belirgin eksikleri var; ödevlerde ve derse hazırlıkta düzenli takip gerekiyor.', 'Sınavlarda öğrendiklerini aktarmakta zorlanıyor, birebir destek çalışması öneriyoruz.']],
  [['Derse ilgili ve merakla katılıyor, sorular soruyor; ders içi davranışları örnek niteliğinde.', 'Dikkatini uzun süre koruyabiliyor, ders akışına hızla uyum sağlıyor.'],
    ['Derse ilgili; dikkati ders ortasında zaman zaman dağılıyor, ön sıralarda oturması yardımcı oluyor.', 'Katılımı iyi, ancak sohbet etme eğilimi zaman zaman ders akışını bölüyor.'],
    ['Dikkatini sürdürmekte zorlanıyor, sık hatırlatma gerekiyor; ders içi katılımı sınırlı.', 'Derse geç hazırlanıyor ve gereç eksikliği yaşıyor; ev-okul iş birliğiyle desteklenmeli.']],
  [['Arkadaşlarıyla uyumlu, grup çalışmalarında iş birliğine açık; akran çatışmalarında arabulucu olabiliyor.', 'İletişimi saygılı ve yapıcı, sınıfta olumlu bir liderlik gösteriyor.'],
    ['Arkadaşlarıyla genel olarak uyumlu; sınıfta daha çekingen, küçük gruplarda kendini daha rahat ifade ediyor.', 'Arkadaş ilişkileri iyi; zaman zaman küçük anlaşmazlıkları kendi başına çözmekte zorlanıyor.'],
    ['Akranlarıyla iletişimde zorlanıyor; grup çalışmalarında geri planda kalıyor, rehberlik desteği planlandı.', 'Çatışma anlarında tepkisel davranabiliyor; öfke yönetimi üzerine çalışılıyor.']],
  [['Görevlerini zamanında yerine getiriyor, eşyalarına özen gösteriyor; kendi hatalarını fark edip düzeltiyor.', 'Zamanını iyi planlıyor, sorumluluklarını hatırlatma beklemeden yerine getiriyor.'],
    ['Sorumluluklarını çoğunlukla yerine getiriyor; zaman planlaması konusunda destek gerekebilir, ödev takvimi birlikte oluşturulabilir.', 'Eşyalarını zaman zaman unutuyor, hatırlatıldığında düzeltiyor.'],
    ['Görevlerini hatırlatma olmadan yerine getirmekte zorlanıyor; zaman yönetimi için evde günlük bir plan önerilir.', 'Eşya ve ödev takibinde sık eksik var; öğretmen-veli iletişimiyle desteklenecek.']],
];
const GORUSME_TOPLANTI = ['Veli toplantısına anne katıldı. Akademik gidişat olumlu; ödev düzeni ve ekran süresi konuşuldu. Evde belirli bir çalışma saati belirlenmesi önerildi.',
  'Veli toplantısına baba katıldı. Derse katılımı ve arkadaş ilişkileri olumlu değerlendirildi; okuma alışkanlığının artırılması istendi.',
  'Veli toplantısına anne ve baba birlikte katıldı. Destek çalışması planlandı, dönem ortasında tekrar görüşülecek.',
  'Veli toplantısına anne katıldı. Sabah derse geç kalma ve uyku düzeni konuşuldu; aile servis saatini kontrol edecek.'];
const GORUSME_TEL = ['Veli telefonla arandı. Öğrencinin sabahları derse geç kalmasının nedenleri görüşüldü; servis saatinin kontrol edilmesi istendi.',
  'Veli okula davet edildi. Ödev teslimlerindeki aksamalar konuşuldu, haftalık takip çizelgesi verildi.', 'Veli ile telefonda görüşüldü. Öğrencinin derslerdeki olumlu gelişimi paylaşıldı, aile desteği için teşekkür edildi.'];
function gelisim(o) {
  if (tum('SELECT 1 x FROM gelisim_donemleri WHERE branch_id = ?', o.id).length) return 0;
  const kalip = tum('SELECT ad, aciklama, sira FROM gelisim_basliklari WHERE branch_id = 1 ORDER BY sira');
  const basliklar = (kalip.length ? kalip : [{ ad: 'Akademik süreç', aciklama: '', sira: 1 }, { ad: 'Dikkat ve ders içi davranış', aciklama: '', sira: 2 }, { ad: 'Sosyal ilişkiler ve iletişim', aciklama: '', sira: 3 }, { ad: 'Sorumluluk ve öz düzenleme', aciklama: '', sira: 4 }])
    .map(b => ins('INSERT INTO gelisim_basliklari (branch_id, ad, aciklama, sira) VALUES (?,?,?,?)', o.id, b.ad, b.aciklama, b.sira));
  const donemKalip = tum('SELECT ad, baslangic, bitis, toplanti_tarihi FROM gelisim_donemleri WHERE branch_id = 1 ORDER BY baslangic');
  let kapali = null;
  for (const [i, d] of donemKalip.entries()) { const id = ins('INSERT INTO gelisim_donemleri (branch_id, ad, baslangic, bitis, toplanti_tarihi, created_at) VALUES (?,?,?,?,?,?)', o.id, d.ad, d.baslangic, d.bitis, d.toplanti_tarihi, simdi); if (i === 0) kapali = { id, d }; }
  if (!kapali) return 0;
  let n = 0;
  for (const s of o.siniflar) {
    const ogretmenler = [s.rehber];
    for (const a of Object.values(s.atama)) if (!ogretmenler.includes(a.ogr) && ogretmenler.length < 4) ogretmenler.push(a.ogr);
    s.ogrenciler.forEach((ogr, oi) => {
      const duzeyi = ogr.yet.genel > 0.5 ? 0 : ogr.yet.genel < -0.5 ? 2 : 1;
      ogretmenler.forEach((t, ti) => basliklar.forEach((b, bi) => {
        if ((s.id + oi + ti) % 11 === 0) return;
        const seviye = rnd() < 0.15 ? sinirla(duzeyi + (rnd() < 0.5 ? -1 : 1), 0, 2) : duzeyi;
        calis('INSERT OR REPLACE INTO gelisim_girisleri (donem_id, baslik_id, student_membership_id, teacher_membership_id, metin, guncelleme) VALUES (?,?,?,?,?,?)', kapali.id, b, ogr.mid, t.mid, METINLER[bi % 4][seviye][(oi + ti) % 2], zaman(kaydir(bugun, -11), '16:00'));
        n++;
      }));
      if (rnd() < 0.7) calis("INSERT INTO gelisim_gorusmeleri (student_membership_id, donem_id, tur, tarih, notu, yazan_membership_id, created_at) VALUES (?,?,'toplanti',?,?,?,?)", ogr.mid, kapali.id, kaydir(bugun, -5), sec(GORUSME_TOPLANTI), s.rehber.mid, zaman(kaydir(bugun, -5), '17:00'));
      if (rnd() < 0.3) calis("INSERT INTO gelisim_gorusmeleri (student_membership_id, donem_id, tur, tarih, notu, yazan_membership_id, created_at) VALUES (?,NULL,'gorusme',?,?,?,?)", ogr.mid, haftaIci(kaydir(bugun, -1 - Math.floor(rnd() * 20))), sec(GORUSME_TEL), s.rehber.mid, simdi - 864e5);
    });
  }
  return n;
}

// ---------- Veliler ----------
function veliKur(o, ogr, kardesVeli) {
  const soyad = ogr.ad.split(' ').slice(-1)[0];
  const anne = rnd() < 0.55;
  const adres = adresUret(o);
  let kisi, vm;
  if (kardesVeli) { kisi = kardesVeli; }
  else kisi = kullaniciEkle(`${sec(anne ? KADIN : ERKEK)} ${soyad}`);
  vm = uyeEkle(kisi, o.id, 'veli');
  calis('INSERT OR IGNORE INTO guardians (parent_membership_id, student_membership_id) VALUES (?,?)', vm.mid, ogr.mid);
  if (!veliUidleri.has(ogr.mid)) veliUidleri.set(ogr.mid, []);
  veliUidleri.get(ogr.mid).push(kisi.uid);
  ogr.veli = kisi; ogr.veliMid = vm.mid;
  calis('INSERT OR REPLACE INTO aile_bilgi (student_membership_id, parent_membership_id, yakinlik, meslek) VALUES (?,?,?,?)', ogr.mid, vm.mid, anne ? 'Anne' : 'Baba', MESLEK[ogr.mid % MESLEK.length]);
  const yakin = `${sec(anne ? ERKEK : KADIN)} ${soyad}`;
  profil(kisi.uid, { email: epostaUret(kisi.ad), telefon2: telRast(), adres, ilce: ILCE[o.kampusId] ?? 'Muratpaşa', yakinAd: yakin, yakinYakinlik: anne ? 'Baba' : 'Anne', yakinTel: telRast() });
  profil(ogr.uid, { adres, ilce: ILCE[o.kampusId] ?? 'Muratpaşa', yakinAd: kisi.ad, yakinYakinlik: anne ? 'Anne' : 'Baba', yakinTel: kisi.tel });
}

// Mevcut öğrencilerin veli kullanıcıları
for (const r of tum(`SELECT g.student_membership_id s, m.user_id u FROM guardians g JOIN memberships m ON m.id = g.parent_membership_id`)) {
  if (!veliUidleri.has(r.s)) veliUidleri.set(r.s, []);
  veliUidleri.get(r.s).push(r.u);
}

// ---------- Duyuru / mesaj ----------
const DUYURULAR = [
  ['Yeni eğitim-öğretim yılı bilgilendirmesi', 'Yeni dönem ders programları, servis saatleri ve yemek listesi okul panosunda ve bu ekranda yayımlanmıştır. Sorularınız için sınıf öğretmeninizle görüşebilirsiniz.', 'veli', -58],
  ['Okul servis saatleri', 'Servis güzergâh ve saatleri güncellenmiştir. Sabah servisleri 07:45, akşam servisleri 16:15 itibarıyla kalkacaktır.', 'veli', -52],
  ['Aylık yemek listesi', 'Kasım ayı yemek listesi hazırlanmıştır. Alerjisi olan öğrencilerimizin velileri lütfen sınıf öğretmenini bilgilendirsin.', 'hepsi', -38],
  ['Öğretmenler kurulu toplantısı', 'Dönem başı öğretmenler kurulu cuma günü son ders sonrası toplantı salonundadır. Katılım zorunludur.', 'ogretmen', -34],
  ['29 Ekim Cumhuriyet Bayramı', '29 Ekim Perşembe günü okulumuz tatildir. Cumhuriyet Bayramımız kutlu olsun.', 'hepsi', -16],
  ['Zümre toplantıları', 'Dönem ortası zümre toplantıları pazartesi günü 8. ders yapılacaktır. Zümre başkanlarından sınav takvimi taslağı beklenmektedir.', 'zumre', -12],
  ['1. dönem veli toplantısı', 'Veli toplantısı 5 Kasım Perşembe günü saat 18:00\'de okulumuzda yapılmıştır. Katılan velilerimize teşekkür ederiz.', 'veli', -9],
  ['Deneme sınavı sonuçları', '3. deneme sınavı sonuçları sistemde yayımlanmıştır. Öğrencilerimiz ve velilerimiz sonuçlarını Sınavlar bölümünden inceleyebilir.', 'veli', -5],
  ['Atatürk Haftası etkinlikleri', '10 Kasım Atatürk\'ü Anma Günü kapsamında okulumuzda anma töreni ve sergi düzenlenecektir. Öğrencilerimiz okul kıyafetiyle gelmelidir.', 'hepsi', -3],
  ['Kış kıyafeti hatırlatması', 'Havaların soğumasıyla birlikte öğrencilerimizin kalın giysilerle ve yedek çorapla gelmesi rica olunur.', 'veli', -1],
];
const SINIF_MESAJLARI = [
  ['Gezi izin belgesi', 'Önümüzdeki hafta yapılacak müze gezisi için izin belgelerinin imzalanıp cuma gününe kadar teslim edilmesi rica olunur.', -20],
  ['Ödev takibi hakkında', 'Bu dönem ödevleri sistem üzerinden takip edebilirsiniz. Çocuğunuzun ödev durumunu Ödevler ekranından görebilirsiniz.', -14],
  ['Veli toplantısı sonrası notlar', 'Toplantıda konuştuğumuz konuları özetledim: ödev düzeni, uyku saati ve okuma alışkanlığı. Desteğiniz için teşekkür ederim.', -8],
];
function iletiler(o) {
  if (bir('SELECT COUNT(*) n FROM iletiler WHERE branch_id = ? AND tur = ?', o.id, 'duyuru').n >= 5) return 0;
  let n = 0;
  const alicilar = rol => {
    const veli = o.ogrenciler.flatMap(x => veliUidleri.get(x.mid) ?? []);
    const hoca = o.ogretmenler.map(t => t.uid);
    const ogr = o.ogrenciler.map(x => x.uid);
    return rol === 'veli' ? veli : rol === 'ogretmen' || rol === 'zumre' ? hoca : [...veli, ...hoca, ...ogr.filter(() => rnd() < 0.5)];
  };
  const okundu = (id, uidler, oran) => { for (const u of new Set(uidler)) if (rnd() < oran) calis('INSERT OR IGNORE INTO ileti_okundu (ileti_id, user_id) VALUES (?,?)', id, u); };
  for (const [baslik, metin, rol, gun] of DUYURULAR) {
    const id = ins('INSERT INTO iletiler (tur, baslik, metin, gonderen_membership_id, branch_id, rol, class_id, created_at) VALUES (?,?,?,?,?,?,?,?)', 'duyuru', baslik, metin, o.mudurMid, o.id, rol, null, zaman(haftaIci(kaydir(bugun, gun)), '09:00'));
    okundu(id, alicilar(rol), gun < -14 ? 0.85 : gun < -5 ? 0.7 : 0.45); n++;
  }
  for (const s of o.siniflar) {
    const gonderen = s.rehberMid ?? o.mudurMid;
    for (const [baslik, metin, gun] of SINIF_MESAJLARI) {
      const id = ins('INSERT INTO iletiler (tur, baslik, metin, gonderen_membership_id, branch_id, rol, class_id, created_at) VALUES (?,?,?,?,?,?,?,?)', 'mesaj', baslik, metin, gonderen, o.id, null, s.id, zaman(haftaIci(kaydir(bugun, gun)), '16:30'));
      okundu(id, s.ogrenciler.flatMap(x => veliUidleri.get(x.mid) ?? []), gun < -10 ? 0.8 : 0.55); n++;
    }
    // Öğrenciye özel mesajlar (devamsızlık, tebrik)
    for (const x of s.ogrenciler) {
      if (x.egilim >= 0.07 && rnd() < 0.7) {
        const id = ins('INSERT INTO iletiler (tur, baslik, metin, gonderen_membership_id, branch_id, rol, class_id, student_membership_id, created_at) VALUES (?,?,?,?,?,?,?,?,?)', 'mesaj', 'Devamsızlık bilgilendirmesi',
          `${x.ad.split(' ')[0]} son haftalarda sık sık derse gelmedi. Durumu birlikte değerlendirmek için sizinle görüşmek isterim; uygun olduğunuzda okula uğrayabilir veya beni arayabilirsiniz.`, gonderen, o.id, null, s.id, x.mid, zaman(haftaIci(kaydir(bugun, -2 - Math.floor(rnd() * 8))), '15:10'));
        okundu(id, veliUidleri.get(x.mid) ?? [], 0.8); n++;
      } else if (x.yet.genel > 1.2 && rnd() < 0.5) {
        const id = ins('INSERT INTO iletiler (tur, baslik, metin, gonderen_membership_id, branch_id, rol, class_id, student_membership_id, created_at) VALUES (?,?,?,?,?,?,?,?,?)', 'mesaj', 'Başarı tebriki',
          `${x.ad.split(' ')[0]} bu dönem derslerde gösterdiği gayret ve başarıyla öne çıkıyor. Kendisini ve sizi tebrik ederim, böyle devam etsin.`, gonderen, o.id, null, s.id, x.mid, zaman(haftaIci(kaydir(bugun, -3 - Math.floor(rnd() * 6))), '14:20'));
        okundu(id, veliUidleri.get(x.mid) ?? [], 0.9); n++;
      }
    }
  }
  return n;
}

// ---------- Zümre, görev, takvim, teslim ----------
const ZUMRE_GUNDEM = ['Ortak yazılı takvimi\nGeride kalan kazanımlar\nSoru bankası paylaşımı', 'Dönem ortası başarı analizi\nYıllık plan kontrolü', 'Ortak sınav hazırlığı\nBireysel destek önerileri', 'Ders materyalleri ve ortak etkinlikler'];
const ZUMRE_KARARLARI = ['Ortak yazılı soruları iki hafta önce zümre başkanına teslim edilecek.', 'Geride kalan kazanımlar için telafi etütleri planlandı.', 'Ders materyalleri ortak klasörde paylaşılacak, eksik olanlar bir sonraki toplantıya kadar tamamlanacak.', 'Deneme sınavı analizleri sınıf bazında incelenip zayıf kazanımlar için destek planı yapılacak.'];
const ZUMRE_YAZILARI = ['Yazılı sorularını ortak klasöre yükledim; incelemek isteyen olursa yorum yazabilir.', 'Arkadaşlar, bu hafta işlediğimiz ünitenin ardından kısa bir tekrar testi hazırladım, isteyen kullanabilir.', 'Yıllık planda bir hafta geride görünüyoruz; pazartesi toplantısında nasıl telafi edeceğimizi konuşalım.', 'Sınav sonrası analizimi paylaşıyorum: en çok yanlış yapılan kazanımlar için ek çalışma kâğıtları hazırlıyorum.'];
function zumre(o) {
  let n = 0;
  const dersOgr = new Map();
  for (const t of o.ogretmenler) for (const d of t.dersler) { if (d === 'Sınıf Öğretmenliği' || d === 'Kulüp') continue; if (!dersOgr.has(d)) dersOgr.set(d, []); dersOgr.get(d).push(t); }
  const varOlan = new Set(tum('SELECT course_id FROM zumre_toplantilari WHERE branch_id = ?', o.id).map(r => r.course_id));
  const gun = k => { let t = kaydir(bugun, k); while (gunNo(t) === 0 || gunNo(t) === 6) t = kaydir(t, 1); return t; };
  for (const [ders, hocalar] of dersOgr) {
    if (!['Türkçe', 'Matematik', 'Fen Bilimleri', 'Sosyal Bilgiler', 'İngilizce', 'Din Kültürü', 'Edebiyat', 'Fizik', 'Kimya', 'Biyoloji', 'Tarih', 'Coğrafya', 'Hayat Bilgisi', 'Bilişim', 'Beden Eğitimi', 'Görsel Sanatlar', 'Müzik'].includes(ders) && !ders.startsWith('T.C.')) continue;
    const cid = dersId(ders);
    if (varOlan.has(cid)) continue;
    let baskan = hocalar.find(t => bir('SELECT zumre_baskani z FROM memberships WHERE id = ?', t.mid).z === 1);
    if (!baskan) { baskan = hocalar[0]; calis('UPDATE memberships SET zumre_baskani = 1 WHERE id = ?', baskan.mid); rolVer(baskan.uid, 'zumre'); }
    const tid = ins('INSERT INTO zumre_toplantilari (branch_id, course_id, baslik, tekrar, baslangic, saat, yer, gundem, olusturan_membership_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)', o.id, cid, `${ders} zümre toplantısı`, 'haftalik', gun(2 + (cid % 3)), '15:30', sec(['Öğretmenler odası', 'Kütüphane', 'Toplantı salonu']), sec(ZUMRE_GUNDEM), baskan.mid, simdi - 20 * 864e5);
    for (const [i, k] of [-35, -21, -7].entries()) {
      const tarih = haftaIci(kaydir(bugun, k));
      calis('INSERT INTO zumre_toplanti_kararlari (branch_id, course_id, toplanti_id, baslik, tarih, saat, yer, karar, yazan_membership_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)', o.id, cid, tid, `${ders} zümre toplantısı`, tarih, '15:30', 'Öğretmenler odası', ZUMRE_KARARLARI[(cid + i) % 4], baskan.mid, zaman(tarih, '17:00'));
    }
    hocalar.slice(0, 3).forEach((t, i) => calis('INSERT INTO zumre_iletileri (branch_id, course_id, membership_id, metin, created_at) VALUES (?,?,?,?,?)', o.id, cid, t.mid, ZUMRE_YAZILARI[(cid + i) % 4], simdi - (5 + i * 23) * 3600000));
    n++;
  }
  return n;
}
function gorevler(o) {
  const var_ = new Set(tum('SELECT user_id FROM gorevler').map(r => r.user_id));
  let n = 0;
  const nob = o.nobetler ?? [];
  if (!nob.length) {
    const adaylar = o.ogretmenler.filter(t => !var_.has(t.uid));
    for (let g = 1; g <= 5; g++) { const t = adaylar[(g * 2) % Math.max(1, adaylar.length)]; if (t) nob.push({ t, g, saat: 2, ad: 'Bahçe nöbeti', yer: 'Okul bahçesi' }); }
    for (let g = 1; g <= 5; g++) { const t = adaylar[(g * 2 + 1) % Math.max(1, adaylar.length)]; if (t) nob.push({ t, g, saat: 5, ad: 'Yemekhane nöbeti', yer: 'Yemekhane' }); }
  }
  for (const x of nob) { calis('INSERT INTO gorevler (user_id, tur, ad, yer, tekrar, day, tarih, saatler) VALUES (?,?,?,?,?,?,?,?)', x.t.uid, 'nobet', x.ad, x.yer, 'haftalik', x.g, null, JSON.stringify([x.saat])); n++; }
  const gorevli = o.ogretmenler.filter(t => !var_.has(t.uid)).slice(-3);
  const gelecek = k => { let t = kaydir(bugun, k); while (gunNo(t) === 0 || gunNo(t) === 6) t = kaydir(t, 1); return t; };
  if (gorevli[0]) { calis('INSERT INTO gorevler (user_id, tur, ad, yer, tekrar, day, tarih, saatler) VALUES (?,?,?,?,?,?,?,?)', gorevli[0].uid, 'gorev', 'Kütüphane sorumlusu', 'Kütüphane', 'haftalik', 2, null, JSON.stringify([6])); n++; }
  if (gorevli[1]) { calis('INSERT INTO gorevler (user_id, tur, ad, yer, tekrar, day, tarih, saatler) VALUES (?,?,?,?,?,?,?,?)', gorevli[1].uid, 'gorev', 'Aralık ayı kutlama programı hazırlığı', 'Konferans salonu', 'tek', null, gelecek(6), JSON.stringify([3, 4])); n++; }
  if (gorevli[2]) { calis('INSERT INTO gorevler (user_id, tur, ad, yer, tekrar, day, tarih, saatler) VALUES (?,?,?,?,?,?,?,?)', gorevli[2].uid, 'gorev', 'Yabancı dil yarışması koordinasyonu', 'Toplantı odası', 'tek', null, gelecek(9), JSON.stringify([7, 8])); n++; }
  return n;
}
function teslim(o) {
  const TESLIM = [['Nermin Aksoy', 'Anneanne'], ['Hasan Yıldız', 'Servis şoförü'], ['Selma Kaya', 'Teyze'], ['Orhan Demir', 'Dede']];
  let n = 0;
  const varMi = new Set(tum('SELECT student_membership_id s FROM teslim_yetkilileri').map(r => r.s));
  o.ogrenciler.forEach((ogr, i) => {
    if (i % 3 || varMi.has(ogr.mid)) return;
    const [ad, yakinlik] = TESLIM[i % TESLIM.length];
    ins('INSERT INTO teslim_yetkilileri (student_membership_id, ad, yakinlik, telefon, created_at) VALUES (?,?,?,?,?)', ogr.mid, ad, yakinlik, '05' + String(300000000 + i * 7919 + o.id * 104729).slice(0, 9), simdi); n++;
  });
  if (o.guvenlik && o.ogrenciler.length) {
    const kayitSayisi = bir('SELECT COUNT(*) n FROM teslim_kayitlari k JOIN memberships m ON m.id = k.student_membership_id WHERE m.branch_id = ?', o.id).n;
    if (kayitSayisi < 5) for (let i = 0; i < 14; i++) {
      const ogr = sec(o.ogrenciler), veliAd = ogr.veli?.ad ?? 'Veli';
      const tarih = kaydir(bugun, -(1 + (i % 6))); const t = haftaIci(tarih);
      calis('INSERT INTO teslim_kayitlari (talep_id, student_membership_id, kisi_ad, yakinlik, guvenlik_user_id, zaman) VALUES (NULL,?,?,?,?,?)', ogr.mid, i % 4 === 0 ? 'Nermin Aksoy' : veliAd, i % 4 === 0 ? 'Anneanne' : 'Veli', o.guvenlik.uid, zaman(t, sec(['15:20', '16:10', '16:25', '12:40'])));
      n++;
    }
  }
  return n;
}

// ---------- Eksik profil / kayıt bilgileri ----------
function eksikProfil() {
  let n = 0;
  const hocaUid = new Map();
  for (const o of okullar) for (const t of o.ogretmenler) hocaUid.set(t.uid, o);
  for (const r of tum(`SELECT u.id, u.full_name ad, (SELECT m.branch_id FROM memberships m WHERE m.user_id = u.id ORDER BY m.id LIMIT 1) b FROM users u WHERE NOT EXISTS (SELECT 1 FROM profil_bilgi p WHERE p.user_id = u.id)`)) {
    const o = okullar.find(x => x.id === r.b) ?? { mahalle: 'Merkez', kampusId: 1 };
    profil(r.id, { email: epostaUret(r.ad), telefon2: telRast(), adres: adresUret(o), ilce: ILCE[o.kampusId] ?? 'Muratpaşa', yakinAd: isim(sec(['E', 'K'])), yakinYakinlik: sec(['Eş', 'Anne', 'Baba', 'Kardeş']), yakinTel: telRast() });
    n++;
  }
  for (const o of okullar) for (const ogr of o.ogrenciler) {
    if (!bir('SELECT 1 x FROM ogrenci_kayit WHERE student_membership_id = ?', ogr.mid)) { ogrenciKaydi(ogr); n++; }
    if (!bir('SELECT 1 x FROM aile_bilgi WHERE student_membership_id = ?', ogr.mid)) {
      const g = bir(`SELECT g.parent_membership_id p FROM guardians g WHERE g.student_membership_id = ? LIMIT 1`, ogr.mid);
      if (g) calis('INSERT OR IGNORE INTO aile_bilgi (student_membership_id, parent_membership_id, yakinlik, meslek) VALUES (?,?,?,?)', ogr.mid, g.p, ogr.mid % 2 ? 'Anne' : 'Baba', MESLEK[ogr.mid % MESLEK.length]);
    }
  }
  return n;
}

// ======================= ANA AKIŞ =======================
if (process.env.GIZLI_ANAHTAR === undefined && !fs.existsSync(path.join(ortam.veriKlasoru, 'gizli.anahtar')) === false) console.log('Uyarı: GIZLI_ANAHTAR tanımsız; dosyadaki anahtar kullanılacak.');
const once = Object.fromEntries(['users', 'memberships', 'yoklama', 'yoklama_kayit', 'sinavlar', 'iletiler'].map(t => [t, bir(`SELECT COUNT(*) n FROM ${t}`).n]));
console.log('Bugün:', bugun, '— önceki sayılar:', JSON.stringify(once));
const t0 = Date.now();
db.exec('BEGIN');
try {
  sure('kampüs/okul kayıtları', () => {
    calis("UPDATE kampusler SET adres = ? WHERE id = 1 AND adres = ''", 'Muratpaşa, Antalya');
    calis("UPDATE kampusler SET adres = ? WHERE id = 3 AND adres = 'Manavgat'", 'Manavgat, Antalya');
    calis("UPDATE kampusler SET telefon = ? WHERE id = 1 AND telefon = ''", '0242 111 11 11');
    calis("UPDATE kampusler SET telefon = ? WHERE id = 3 AND telefon = ''", '0242 333 33 33');
    sistemRolleriKur();
  });
  for (const b of tum('SELECT * FROM branches ORDER BY id')) if (!TANIMLAR.some(t => t.id === b.id)) { const o = mevcutOkulYukle(b); o.mahalle = ILCE[b.campus_id] ?? 'Merkez'; okullar.push(o); }
  const eskiOkulSayisi = okullar.length;
  // Mevcut okulların eksik açıklamaları
  for (const o of okullar) {
    const b = bir('SELECT * FROM branches WHERE id = ?', o.id);
    if (!b.aciklama) calis('UPDATE branches SET aciklama = ?, telefon = CASE WHEN telefon = \'\' THEN ? ELSE telefon END, eposta = CASE WHEN eposta = \'\' THEN ? ELSE eposta END WHERE id = ?', OKUL_ACIKLAMA[o.tur]?.(o.ad) ?? '', '0242 000 00 ' + (10 + o.id), ascii(o.ad).replace(/\./g, '') + '@neademy.example', o.id);
  }
  const yeniler = sure('yeni okullar, sınıflar, öğrenciler', () => TANIMLAR.map(t => { const o = yeniOkulKur(t); return o; }));
  sure('öğretmen kadrosu ve ders atamaları', () => yeniler.forEach(kadroKur));
  for (const o of okullar) o.yon = [];
  sure('yönetim, rehber, güvenlik', () => okullar.forEach(yonetimKur));
  const yerles = sure('haftalık ders programları', () => programYap(yeniler));
  console.log('  yerleşemeyen ders saati:', yerles);

  // Kardeş çiftleri ve veliler (yeni okullar)
  sure('veliler ve kardeşler', () => {
    const bul = ad => okullar.find(o => o.ad === ad);
    const sira = { ilk5: bul('Manavgat İlkokulu'), orta: bul('Manavgat Ortaokulu'), lise: bul('Manavgat Lisesi'), alanyaIlk: bul('Alanya İlkokulu'), alanyaOrta: bul('Alanya Ortaokulu'), anaokul: bul('Pilot Anaokulu'), pilotIlk: bul('Pilot İlkokulu') };
    const kardesVeli = new Map(); // yeni öğrenci mid -> veli kullanıcı (var olan)
    const yeniAdlar = new Map();
    const cift = (kucukOkul, buyukOkul, n, kucukDuzeyler, buyukDuzeyler) => {
      const kucukler = karistir(kucukOkul.ogrenciler.filter(x => kucukDuzeyler.includes(x.sinif.duzey) && !x.kardes));
      const buyukler = karistir(buyukOkul.ogrenciler.filter(x => buyukDuzeyler.includes(x.sinif.duzey) && !x.kardes));
      for (let i = 0; i < n && i < kucukler.length && i < buyukler.length; i++) {
        const k = kucukler[i], b = buyukler[i];
        k.kardes = b; b.kardes = k;
        if (buyukOkul.mevcut) { // büyük zaten ailesi olan öğrenci: yeni küçük onun soyadını ve velisini alır
          const soyad = b.ad.split(' ').slice(-1)[0];
          const yeniAd = isim(k.cins, soyad); calis('UPDATE users SET full_name = ? WHERE id = ?', yeniAd, k.uid); k.ad = yeniAd;
          const vu = (veliUidleri.get(b.mid) ?? [])[0];
          if (vu) kardesVeli.set(k.mid, { uid: vu, ad: bir('SELECT full_name ad FROM users WHERE id = ?', vu).ad, tel: bir('SELECT phone t FROM users WHERE id = ?', vu).t });
        } else { // ikisi de yeni: büyük olan küçüğün soyadını alır; veliyi küçük için kuracağız, büyük onu paylaşır
          const soyad = k.ad.split(' ').slice(-1)[0];
          const yeniAd = isim(b.cins, soyad); calis('UPDATE users SET full_name = ? WHERE id = ?', yeniAd, b.uid); b.ad = yeniAd;
          b.kardesVeliKaynak = k;
        }
      }
    };
    cift(sira.ilk5, sira.orta, 6, [3, 4], [5, 6]);
    cift(sira.orta, sira.lise, 6, [7, 8], [9, 10]);
    cift(sira.alanyaIlk, sira.alanyaOrta, 5, [2, 3, 4], [5, 6, 7]);
    cift(sira.anaokul, sira.pilotIlk, 4, [0], [1, 2]);
    for (const o of yeniler) {
      const sirali = [...o.ogrenciler].sort((a, b) => (a.kardesVeliKaynak ? 1 : 0) - (b.kardesVeliKaynak ? 1 : 0));
      for (const ogr of sirali) {
        if (ogr.kardesVeliKaynak) veliKur(o, ogr, ogr.kardesVeliKaynak.veli); // kaynağın velisi zaten kurulmuş olmalı
        else veliKur(o, ogr, kardesVeli.get(ogr.mid) ?? null);
      }
    }
    // Öğretmen aynı zamanda veli: Manavgat Ortaokulu matematik öğretmeni, Manavgat İlkokulu'ndaki bir öğrencinin velisi
    const hoca = sira.orta.ogretmenler.find(t => t.dersler[0] === 'Matematik' && !t.zumreBaskani) ?? sira.orta.ogretmenler[2];
    const hedef = sira.ilk5.ogrenciler.find(x => !x.kardes && x.sinif.duzey === 2);
    if (hoca && hedef) {
      const vm = uyeEkle({ uid: hoca.uid, ad: hoca.ad }, sira.ilk5.id, 'veli');
      calis('INSERT OR IGNORE INTO guardians (parent_membership_id, student_membership_id) VALUES (?,?)', vm.mid, hedef.mid);
      calis('INSERT OR REPLACE INTO aile_bilgi (student_membership_id, parent_membership_id, yakinlik, meslek) VALUES (?,?,?,?)', hedef.mid, vm.mid, 'Baba', 'Öğretmen');
      veliUidleri.get(hedef.mid).push(hoca.uid);
      kisiRef.ogretmenVeli = { uid: hoca.uid, mid: hoca.mid, ad: hoca.ad, cocuk: hedef.ad };
    }
  });

  const tumOkullar = okullar;
  sure('yoklama / konu / ödev (tüm okullar)', () => tumOkullar.forEach(etkinlik));
  console.log('  yoklama:', sayim.yoklama, 'konu:', sayim.konu, 'ödev:', sayim.odev, 'ödev durumu:', sayim.odevDurum);
  const e = sure('etütler', () => tumOkullar.reduce((a, o) => a + etutler(o), 0)); console.log('  etüt:', e);
  const sn = sure('sınavlar (deneme + yazılı + performans)', () => tumOkullar.reduce((a, o) => a + sinavlar(o), 0)); console.log('  sınav:', sn);
  const kl = sure('kulüpler', () => tumOkullar.reduce((a, o) => a + kulupler(o), 0)); console.log('  kulüp:', kl);
  const gl = sure('gelişim raporu', () => tumOkullar.reduce((a, o) => a + gelisim(o), 0)); console.log('  gelişim girişi:', gl);
  const il = sure('duyuru / mesaj', () => tumOkullar.reduce((a, o) => a + iletiler(o), 0)); console.log('  ileti:', il);
  const zm = sure('zümreler', () => tumOkullar.reduce((a, o) => a + zumre(o), 0)); console.log('  zümre:', zm);
  const gr = sure('nöbet / görev', () => tumOkullar.reduce((a, o) => a + gorevler(o), 0)); console.log('  görev:', gr);
  const ts = sure('teslim yetkilileri / kayıtları', () => tumOkullar.reduce((a, o) => a + teslim(o), 0)); console.log('  teslim:', ts);
  console.log('  eksik profil/kayıt:', sure('profil, kayıt bilgisi', eksikProfil));

  // Okul takvimi, başkanlar toplantısı
  sure('tatiller, başkanlar toplantısı', () => {
    if (!bir('SELECT COUNT(*) n FROM tatiller').n)
      for (const [bas, bit, ad, tur] of [['2026-10-29', '2026-10-29', 'Cumhuriyet Bayramı', 'resmi'], ['2026-11-10', '2026-11-10', "Atatürk'ü Anma Günü", 'ozel'], ['2027-01-18', '2027-01-29', 'Yarıyıl tatili', 'ara'], ['2027-04-23', '2027-04-23', 'Ulusal Egemenlik ve Çocuk Bayramı', 'resmi'], ['2027-05-19', '2027-05-19', "Atatürk'ü Anma, Gençlik ve Spor Bayramı", 'resmi']])
        calis('INSERT INTO tatiller (baslangic, bitis, ad, tur, created_at) VALUES (?,?,?,?,?)', bas, bit, ad, tur, simdi);
    if (bir('SELECT COUNT(*) n FROM baskan_toplantilari').n < 6) {
      const ky = kisiRef.kurumYonetici;
      const olustur = bir(`SELECT user_id u FROM memberships WHERE role = 'yonetim' AND gorev = 'kurum' ORDER BY id LIMIT 1`).u;
      for (const [bas, tarih, saat, gundem, karar] of [['Dönem başı müdürler kurulu', haftaIci(kaydir(bugun, -50)), '10:00', 'Okul yılı hedefleri\nDers programı uyumu\nNöbet ve servis düzeni', 'Okullar arası ortak sınav takvimi oluşturulacak; haftalık ders programları ekim ayı sonuna kadar kesinleşecek.'],
        ['Aylık müdürler toplantısı', haftaIci(kaydir(bugun, -18)), '10:00', 'Deneme sınavı sonuçları\nVeli toplantısı planı', 'Veli toplantıları aynı hafta içinde tüm okullarda yapılacak; deneme sınavı analizleri kurum geneli raporlanacak.'],
        ['Kasım ayı müdürler toplantısı', haftaIci(kaydir(bugun, 6)), '10:00', 'Yarıyıl sınav takvimi\nKulüp etkinlikleri\nKampüs ziyaretleri', '']]) {
        const id = ins('INSERT INTO baskan_toplantilari (branch_id, baslik, tarih, saat, yer, gundem, karar, karar_yazan_user_id, karar_zamani, olusturan_user_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)', 1, bas, tarih, saat, 'Merkez toplantı salonu', gundem, karar, karar ? olustur : null, karar ? zaman(tarih, '12:00') : null, olustur, simdi - 60 * 864e5);
        for (const o of okullar) calis('INSERT OR IGNORE INTO baskan_toplanti_okullari (toplanti_id, branch_id) VALUES (?,?)', id, o.id);
      }
    }
  });

  // ---------- Hızlı giriş kişileri ----------
  sure('hızlı giriş listesi', () => {
    const gruplar = [];
    const kisi = (etiket, alt, uid, mid) => ({ etiket, alt, user_id: uid, membership_id: mid });
    const bulOkul = ad => okullar.find(o => o.ad === ad);
    const ilk5 = bulOkul('Manavgat İlkokulu'), orta = bulOkul('Manavgat Ortaokulu'), lise = bulOkul('Manavgat Lisesi'), anaokul = bulOkul('Pilot Anaokulu'), alanyaIlk = bulOkul('Alanya İlkokulu');
    const ogretmenBul = (o, ders, i = 0) => o.ogretmenler.filter(t => t.dersler[0] === ders)[i];
    const ogretmenKisi = (o, t, rol) => kisi(`${t.ad}`, `${rol} · ${o.ad}`, t.uid, t.mid);
    // Yönetim
    const kurum = (() => {
      const k = kullaniciEkle('Nazlı Akant');
      const m = uyeEkle(k, 1, 'yonetim', null, 'kurum');
      const kc = kullaniciEkle('Kemal Akant'); const m2 = uyeEkle(kc, 1, 'yonetim', null, 'kurum'); rolVer(kc.uid, 'kurucu');
      const tk = kullaniciEkle('Serkan Teknik'); const m3 = uyeEkle(tk, 1, 'yonetim', null, 'okul'); rolVer(tk.uid, 'teknik');
      for (const x of [k, kc, tk]) profil(x.uid, { email: epostaUret(x.ad), telefon2: telRast(), adres: 'Muratpaşa, Antalya' });
      return [kisi(k.ad, 'Kurum yöneticisi · tüm okullar', k.uid, m.mid), kisi(kc.ad, 'Kurucu · tüm okullar', kc.uid, m2.mid), kisi(tk.ad, 'Teknik ekip', tk.uid, m3.mid)];
    })();
    gruplar.push({ ad: 'Kurum', kisiler: kurum });
    gruplar.push({ ad: 'Okul yönetimi', kisiler: okullar.flatMap(o => [o.mudur && kisi(o.mudur.ad, `Müdür · ${o.ad}`, o.mudur.uid, o.mudurMid), o.mudurYrd && kisi(o.mudurYrd.ad, `Müdür yardımcısı · ${o.ad}`, o.mudurYrd.uid, o.mudurYrd.mid)].filter(Boolean)) });
    gruplar.push({ ad: 'Rehberlik ve güvenlik', kisiler: okullar.flatMap(o => [o.rehber && kisi(o.rehber.ad, `Rehber öğretmen · ${o.ad}`, o.rehber.uid, o.rehber.mid), o.guvenlik && kisi(o.guvenlik.ad, `Güvenlik · ${o.ad}`, o.guvenlik.uid, o.guvenlik.mid)].filter(Boolean)) });
    const zb = [];
    for (const [o, ders] of [[orta, 'Matematik'], [orta, 'Fen Bilimleri'], [lise, 'Tarih'], [lise, 'Edebiyat'], [ilk5, 'Sınıf Öğretmenliği']]) {
      const t = ogretmenBul(o, ders); if (t) zb.push(kisi(t.ad, `Zümre başkanı (${ders === 'Sınıf Öğretmenliği' ? 'sınıf öğretmenleri' : ders}) · ${o.ad}`, t.uid, t.mid));
    }
    gruplar.push({ ad: 'Zümre başkanları', kisiler: zb });
    const og = [];
    for (const [o, ders, i, rol] of [[lise, 'Tarih', 1, 'Tarih öğretmeni'], [lise, 'Tarih', 0, 'Tarih öğretmeni (zümre başkanı)'], [orta, 'Fen Bilimleri', 1, 'Fen bilimleri öğretmeni'], [orta, 'Fen Bilimleri', 2, 'Fen bilimleri öğretmeni'], [orta, 'Matematik', 1, 'Matematik öğretmeni'], [orta, 'Matematik', 2, 'Matematik öğretmeni'],
      [lise, 'Matematik', 1, 'Matematik öğretmeni'], [orta, 'Türkçe', 1, 'Türkçe öğretmeni'], [lise, 'Edebiyat', 1, 'Edebiyat öğretmeni'], [orta, 'İngilizce', 0, 'İngilizce öğretmeni'], [lise, 'Fizik', 0, 'Fizik öğretmeni'], [orta, 'Beden Eğitimi', 0, 'Beden eğitimi öğretmeni']]) {
      const t = ogretmenBul(o, ders, i) ?? ogretmenBul(o, ders, 0); if (t && !og.some(x => x.user_id === t.uid)) og.push(ogretmenKisi(o, t, rol));
    }
    for (const o of [ilk5, anaokul, alanyaIlk]) { const s = o.siniflar[0]; og.push(ogretmenKisi(o, s.sinifOgretmeni, o.tur === 'Anaokulu' ? 'Anasınıfı öğretmeni' : `Sınıf öğretmeni (${s.ad})`)); }
    for (const o of okullar.filter(x => x.mevcut)) { const t = o.ogretmenler.filter(x => x.dersler.length && !x.zumreBaskani).sort((a, b) => b.yuk - a.yuk)[0]; if (t && bir('SELECT full_name n FROM users WHERE id = ?', t.uid).n !== 'Tarık Husny') og.push(ogretmenKisi(o, t, `${t.dersler[0] ?? ''} öğretmeni`)); }
    if (kisiRef.ogretmenVeli) og.push(kisi(kisiRef.ogretmenVeli.ad, `Öğretmen + veli (çocuğu ${kisiRef.ogretmenVeli.cocuk}) · çok profilli`, kisiRef.ogretmenVeli.uid, kisiRef.ogretmenVeli.mid));
    gruplar.push({ ad: 'Öğretmenler', kisiler: og });
    const ogrenci = [], veli = [];
    for (const [o, duzey] of [[anaokul, 0], [ilk5, 1], [ilk5, 4], [orta, 6], [orta, 8], [lise, 9], [lise, 12], [alanyaIlk, 2]]) {
      const x = o.ogrenciler.find(z => z.sinif.duzey === duzey && !z.kardes) ?? o.ogrenciler.find(z => z.sinif.duzey === duzey);
      if (!x) continue;
      ogrenci.push(kisi(x.ad, `${duzey === 0 ? 'Anasınıfı' : duzey + '. sınıf'} öğrencisi (${x.sinif.ad}) · ${o.ad}`, x.uid, x.mid));
      if (x.veli) veli.push(kisi(x.veli.ad, `${x.ad.split(' ')[0]} adlı öğrencinin velisi · ${o.ad}`, x.veli.uid, x.veliMid));
    }
    const kardesli = okullar.flatMap(o => o.ogrenciler).find(x => x.kardes && x.veli && !x.sinif.o.mevcut && x.kardes.sinif.o.id !== x.sinif.o.id);
    if (kardesli) veli.push(kisi(kardesli.veli.ad, `İki okulda çocuğu var (${kardesli.sinif.o.ad} + ${kardesli.kardes.sinif.o.ad}) · çok profilli`, kardesli.veli.uid, kardesli.veliMid));
    gruplar.push({ ad: 'Öğrenciler', kisiler: ogrenci });
    gruplar.push({ ad: 'Veliler', kisiler: veli });
    const okulBazli = [];
    for (const o of okullar.filter(x => x.mevcut)) {
      const x = o.ogrenciler[Math.floor(o.ogrenciler.length / 2)];
      if (x) okulBazli.push(kisi(x.ad, `Öğrenci (${x.sinif.ad}) · ${o.ad}`, x.uid, x.mid));
      const v = x && veliUidleri.get(x.mid)?.[0];
      if (v) { const vm = bir(`SELECT m.id mid FROM memberships m WHERE m.user_id = ? AND m.branch_id = ? AND m.role = 'veli'`, v, o.id); if (vm) okulBazli.push(kisi(bir('SELECT full_name n FROM users WHERE id = ?', v).n, `Veli · ${o.ad}`, v, vm.mid)); }
    }
    gruplar.push({ ad: 'Diğer okullar (mevcut veri)', kisiler: okulBazli });
    // Sağlama: üyelik gerçekten bu kullanıcının mı
    for (const g of gruplar) g.kisiler = g.kisiler.filter(k => k && bir('SELECT 1 x FROM memberships WHERE id = ? AND user_id = ?', k.membership_id, k.user_id));
    // Fotoğrafı olmayan birkaç kişiye mevcut örnek fotoğraflar
    const fotolu = [[ogrenci[1], '/foto/ogrenci-ilkokul.jpg'], [ogrenci[5], '/foto/ogrenci-lise.jpg'], [gruplar[1].kisiler[0], '/foto/mudur-ilkokul.jpg']];
    for (const [k, f] of fotolu) if (k && fs.existsSync(path.join(ortam.kok ?? '.', 'public', f)) !== undefined) calis('UPDATE users SET foto = ? WHERE id = ? AND foto IS NULL', f, k.user_id);
    fs.writeFileSync(path.join(ortam.veriKlasoru, 'hizli-giris.json'), JSON.stringify({ olusturma: simdi, gruplar }, null, 1));
    console.log('  hızlı giriş kişisi:', gruplar.reduce((a, g) => a + g.kisiler.length, 0));
  });

  db.exec('COMMIT');
} catch (e) {
  db.exec('ROLLBACK');
  console.error('HATA — işlem geri alındı:', e);
  process.exit(1);
}
const sonra = Object.fromEntries(['users', 'memberships', 'yoklama', 'yoklama_kayit', 'sinavlar', 'iletiler'].map(t => [t, bir(`SELECT COUNT(*) n FROM ${t}`).n]));
console.log('Bitti. Toplam süre:', ((Date.now() - t0) / 1000).toFixed(1), 'sn — sonraki sayılar:', JSON.stringify(sonra));
db.exec('PRAGMA wal_checkpoint(TRUNCATE)');
