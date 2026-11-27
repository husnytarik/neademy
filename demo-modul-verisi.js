// Canlı demo veritabanına rehberlik, öğrenci sağlık kartı/revir ve servis verisi ekler (idempotent: tablolar boşsa çalışır).
// Kullanım (sunucu kapalıyken, üretim ortamı değişkenleriyle): node --no-warnings demo-modul-verisi.js
import fs from 'node:fs';
import path from 'node:path';
import { db } from './db.js';
import { ortam } from './ortam.js';
import { sifrele } from './gizli.js';
import './rehberlik.js';
import './saglik.js';
import './servis.js';

const BASLA = '2026-09-14', BUGUN = '2026-11-27', TATIL = '2026-10-29';
let tohum = 20261127;
const rnd = () => ((tohum = (tohum * 1664525 + 1013904223) >>> 0) / 4294967296);
const sec = d => d[Math.floor(rnd() * d.length)];
const olasilik = p => rnd() < p;
const tum = (s, ...a) => db.prepare(s).all(...a);
const bir = (s, ...a) => db.prepare(s).get(...a);
const calis = (s, ...a) => db.prepare(s).run(...a);

const gunler = [];
for (let d = new Date(BASLA + 'T12:00:00Z'); d.toISOString().slice(0, 10) <= BUGUN; d.setUTCDate(d.getUTCDate() + 1)) {
  const s = d.toISOString().slice(0, 10), h = d.getUTCDay();
  if (h !== 0 && h !== 6 && s !== TATIL) gunler.push(s);
}
const gunSec = (min = 0) => gunler[Math.min(gunler.length - 1, min + Math.floor(rnd() * (gunler.length - min)))];
const saatSec = () => sec(['08:50', '09:40', '10:30', '11:20', '12:30', '13:20', '14:10']);
const tamSaat = g => new Date(g + 'T10:00:00+03:00').getTime();

const hizli = (() => { try { return JSON.parse(fs.readFileSync(path.join(ortam.veriKlasoru, 'hizli-giris.json'), 'utf8')); } catch { return { gruplar: [] }; } })();
const hizliMid = new Set(hizli.gruplar.flatMap(g => g.kisiler).map(k => k.membership_id));

const GORUSME_KONULARI = [
  ['Uyum ve arkadaşlık', 'Sınıfta kendini yalnız hissettiğini söyledi; arkadaş ilişkileri konuşuldu.', 'Dinlendi, sınıf öğretmeniyle iş birliği planlandı.'],
  ['Ders çalışma alışkanlığı', 'Ödevlerini düzenli yapmakta zorlanıyor; evde çalışma ortamı konuşuldu.', 'Haftalık çalışma planı birlikte hazırlandı.'],
  ['Sınav kaygısı', 'Sınavlardan önce uyku ve iştah sorunu yaşıyor.', 'Nefes ve planlama teknikleri gösterildi, 2 hafta sonra tekrar görülecek.'],
  ['Devamsızlık', 'Son haftalarda geç kalma ve devamsızlık arttı; ailedeki değişiklikler gündemde.', 'Veli ile telefon görüşmesi yapıldı.'],
  ['Davranış ve sınıf kuralları', 'Ders içinde söz almadan konuşma; kurallar birlikte gözden geçirildi.', 'Küçük hedefler belirlendi, öğretmen geri bildirimi istendi.'],
  ['Akran zorbalığı şüphesi', 'Teneffüste dışlandığını belirtti; bilgi gizli tutuldu.', 'Gözlem başlatıldı, nöbetçi öğretmen bilgilendirildi.'],
  ['Kariyer ve alan seçimi', 'İlgi alanları ve güçlü yönleri üzerine konuşuldu.', 'İlgi envanteri verildi.'],
  ['Motivasyon', 'Derslere ilgisi düştü; hedef belirleme çalışması yapıldı.', 'Kısa vadeli hedefler yazıldı.'],
  ['Aile ile iletişim', 'Veli görüşmesi: evdeki rutinler ve ekran süresi.', 'Ekran süresi için ortak kurallar önerildi.'],
  ['Dikkat ve odaklanma', 'Derste dikkatinin dağıldığı gözlemlendi; oturma düzeni değiştirildi.', 'Öğretmenle yer değişikliği ve kısa molalar planlandı.'],
];

// ---------- Okul bazlı kişi bulma ----------
const okullar = tum('SELECT id, name FROM branches ORDER BY id');
function okulKisi(subeId, kod) {
  return bir(`SELECT m.id mid, m.user_id uid FROM kullanici_roller k JOIN roller r ON r.id = k.rol_id JOIN memberships m ON m.user_id = k.user_id AND m.branch_id = ? AND m.role = 'yonetim' AND m.status = 'aktif' WHERE r.kod = ? ORDER BY m.id LIMIT 1`, subeId, kod);
}
const okulYonetici = subeId => bir(`SELECT m.id mid, m.user_id uid FROM memberships m WHERE m.branch_id = ? AND m.role = 'yonetim' AND m.status = 'aktif' ORDER BY m.id LIMIT 1`, subeId);
const ogrenciler = subeId => tum(`SELECT m.id mid, m.user_id uid, u.full_name ad, cs.class_id sinifId, c.name sinif FROM memberships m JOIN users u ON u.id = m.user_id
  JOIN class_students cs ON cs.student_membership_id = m.id JOIN classes c ON c.id = cs.class_id WHERE m.branch_id = ? AND m.role = 'ogrenci' AND m.status = 'aktif' ORDER BY m.id`, subeId);

const sayi = { gorusme: 0, form: 0, cevap: 0, kart: 0, olcum: 0, olay: 0, servis: 0, servisOgr: 0 };

// ---------- Rehberlik ----------
const TEST = {
  ad: 'Çalışma alışkanlıkları envanteri', tur: 'test', hedef: 'ogrenci',
  aciklama: 'Ders çalışma düzenini görmek için kısa bir test. Doğru ya da yanlış cevap yoktur.',
  sorular: [
    { metin: 'Ders çalışmak için belirli bir saatim var.', tip: 'likert' },
    { metin: 'Ödevlerimi son güne bırakırım.', tip: 'likert', ters: true },
    { metin: 'Çalışırken telefonumu uzağa koyarım.', tip: 'likert' },
    { metin: 'Anlamadığım konuyu öğretmenime sorarım.', tip: 'evet-hayir' },
    { metin: 'Bir gün içinde ders çalışmaya ne kadar zaman ayırırsın?', tip: 'secenek', secenekler: [{ metin: '1 saatten az', puan: 0 }, { metin: '1-2 saat', puan: 2 }, { metin: '2-3 saat', puan: 3 }, { metin: '3 saatten fazla', puan: 4 }] },
  ],
  yorumlar: [
    { min: 0, max: 9, baslik: 'Gelişime açık', aciklama: 'Çalışma planı hazırlayarak başlayabilirsin; rehber öğretmenle görüşmeni öneririz.' },
    { min: 10, max: 16, baslik: 'Orta düzey', aciklama: 'Düzenin oturmaya başlamış. Planını sabit saatlere bağlamak verimini artırır.' },
    { min: 17, max: 40, baslik: 'Güçlü alışkanlıklar', aciklama: 'Çalışma düzenin iyi görünüyor, böyle devam et.' },
  ],
};
const ANKET = {
  ad: 'Okul yaşamı memnuniyet anketi', tur: 'anket', hedef: 'veli', anonim: 1,
  aciklama: 'Dönem ortası görüşleriniz bizim için değerli. Anket anonimdir.',
  sorular: [
    { metin: 'Okulun öğrencime yaklaşımından memnunum.', tip: 'likert' },
    { metin: 'Öğretmenlerle iletişim kurmak kolay.', tip: 'likert' },
    { metin: 'Okul güvenliği konusunda kendimi rahat hissediyorum.', tip: 'likert' },
    { metin: 'Çocuğum okula severek gidiyor.', tip: 'evet-hayir' },
    { metin: 'Eklemek istediğiniz görüş ya da öneri', tip: 'metin' },
  ],
  yorumlar: [],
};
const SERBEST = ['Servis saatleri biraz erken.', 'Öğretmenlerimizden çok memnunuz.', 'Etüt saatleri artırılabilir.', 'Kantin menüsü çeşitlendirilebilir.', 'Veli toplantıları daha sık olsun.', null, null, null];

const puanla = (sorular, cevap) => sorular.reduce((t, s, i) => {
  const c = cevap[i];
  if (s.tip === 'likert') return t + (s.ters ? 6 - c : c);
  if (s.tip === 'evet-hayir') return t + (s.ters ? (c === 1 ? 1 : 0) : (c === 0 ? 1 : 0));
  if (s.tip === 'secenek') return t + s.secenekler[c].puan;
  return t;
}, 0);
const cevapUret = (sorular, egilim) => sorular.map(s => {
  if (s.tip === 'likert') return Math.max(1, Math.min(5, Math.round(egilim * 5 + (rnd() - 0.5) * 2.2)));
  if (s.tip === 'evet-hayir') return rnd() < egilim ? 0 : 1;
  if (s.tip === 'secenek') return Math.min(s.secenekler.length - 1, Math.floor(rnd() * 4 * egilim + rnd() * 1.4));
  return sec(SERBEST);
});

function rehberlik(o, ogr) {
  const rehber = okulKisi(o.id, 'rehber') || okulYonetici(o.id);
  if (!rehber) return;
  // Görüşmeler: öğrencilerin ~%5'i (demo kişileri her zaman)
  for (const s of ogr) {
    if (!(hizliMid.has(s.mid) || olasilik(0.05))) continue;
    for (let n = hizliMid.has(s.mid) ? 2 : 1 + (olasilik(0.3) ? 1 : 0); n > 0; n--) {
      const [konu, ozet, yapilan] = sec(GORUSME_KONULARI);
      const tarih = gunSec(n === 1 ? 0 : 15), gizli = /zorbal|Devams/.test(konu) || olasilik(0.12) ? 1 : 0;
      const takip = olasilik(0.45) ? gunler[Math.min(gunler.length - 1, gunler.indexOf(tarih) + 10)] : '';
      const takipTamam = takip && takip < BUGUN && olasilik(0.7) ? 1 : 0;
      calis(`INSERT INTO rehber_gorusmeleri (student_membership_id, branch_id, tarih, saat, tur, konu, ozet, yapilan, takip_tarihi, takip_tamam, gizli, yazan_user_id, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        s.mid, o.id, tarih, saatSec(), sec(['ogrenci', 'ogrenci', 'veli', 'ogretmen']), sifrele(konu), sifrele(ozet), sifrele(yapilan), takip, takipTamam, gizli, rehber.uid, tamSaat(tarih), tamSaat(tarih));
      sayi.gorusme++;
    }
  }
  // Test ve anket
  for (const F of [TEST, ANKET]) {
    const r = calis(`INSERT INTO rehber_formlar (branch_id, tur, ad, aciklama, hedef, sinif_ids, sorular, yorumlar, anonim, sonuc_goster, durum, son_tarih, olusturan_user_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      o.id, F.tur, F.ad, F.aciklama, F.hedef, '[]', JSON.stringify(F.sorular), JSON.stringify(F.yorumlar), F.anonim ? 1 : 0, F.tur === 'test' ? 1 : 0, 'acik', '2026-12-18', rehber.uid, tamSaat(gunSec(20)));
    const fid = Number(r.lastInsertRowid);
    sayi.form++;
    for (const s of ogr) {
      if (!(hizliMid.has(s.mid) || olasilik(0.55))) continue;
      const egilim = 0.35 + rnd() * 0.6;
      const cevap = cevapUret(F.sorular, egilim);
      const puan = F.tur === 'test' ? puanla(F.sorular, cevap) : null;
      if (F.hedef === 'ogrenci') {
        calis('INSERT OR IGNORE INTO rehber_cevaplar (form_id, student_membership_id, cevaplayan_membership_id, cevaplar, puan, giren_user_id, created_at) VALUES (?,?,?,?,?,?,?)', fid, s.mid, s.mid, JSON.stringify(cevap), puan, s.uid, tamSaat(gunSec(25)));
        sayi.cevap++;
      } else {
        const v = bir(`SELECT g.parent_membership_id p, m.user_id uid FROM guardians g JOIN memberships m ON m.id = g.parent_membership_id AND m.status = 'aktif' WHERE g.student_membership_id = ? LIMIT 1`, s.mid);
        if (!v) continue;
        calis('INSERT OR IGNORE INTO rehber_cevaplar (form_id, student_membership_id, cevaplayan_membership_id, cevaplar, puan, giren_user_id, created_at) VALUES (?,?,?,?,?,?,?)', fid, s.mid, v.p, JSON.stringify(cevap), null, v.uid, tamSaat(gunSec(25)));
        sayi.cevap++;
      }
    }
  }
}

// ---------- Sağlık ----------
const ALERJI = ['Fıstık alerjisi', 'Süt ürünleri alerjisi', 'Arı sokması alerjisi', 'Polen alerjisi', 'Yumurta alerjisi', 'Penisilin alerjisi'];
const KRONIK = ['Astım', 'Tip 1 diyabet', 'Epilepsi (kontrol altında)', 'Çölyak', 'Egzama'];
const SIKAYET = [['Baş ağrısı', 'Dinlendirildi, su içirildi.', 'sinifa'], ['Karın ağrısı', 'Dinlendirildi, ısı uygulandı.', 'sinifa'], ['Düşme sonucu diz yarası', 'Yara temizlendi, bandaj yapıldı.', 'sinifa'], ['Ateş', 'Ateş ölçüldü (37.9), veli arandı.', 'eve'], ['Burun kanaması', 'Soğuk uygulandı, başı öne eğdirildi.', 'sinifa'], ['Bayılma hissi', 'Yatırıldı, şekerli su verildi.', 'ilac'], ['Kol bileği ağrısı', 'Spor dersinde incinme; buz uygulandı, veli bilgilendirildi, sevk edildi.', 'hastane'], ['Mide bulantısı', 'Dinlendirildi, veli bilgilendirildi.', 'eve']];
function saglik(o, ogr) {
  const hemsire = okulKisi(o.id, 'rehber') || okulYonetici(o.id);
  if (!hemsire) return;
  const kan = ['A Rh+', 'A Rh-', 'B Rh+', 'B Rh-', 'AB Rh+', '0 Rh+', '0 Rh+', '0 Rh-'];
  for (const s of ogr) {
    const demo = hizliMid.has(s.mid);
    const alerji = demo && s.mid % 2 ? 'Fıstık alerjisi' : olasilik(0.07) ? sec(ALERJI) : '';
    const kronik = olasilik(0.03) ? sec(KRONIK) : '';
    const ilac = /Astım/.test(kronik) ? 'Ventolin (gerektiğinde)' : /diyabet/.test(kronik) ? 'İnsülin (veli kontrolünde)' : '';
    const g = [sec(kan), olasilik(0.18) ? 1 : 0, sifrele(alerji), sifrele(kronik), sifrele(ilac), sifrele(''), sifrele(''), sifrele(olasilik(0.02) ? 'Glütensiz' : ''), sifrele(sec(['', 'Dr. Ayşe Kaya', 'Dr. Murat Aksoy'])), sec(['Manavgat Devlet Hastanesi', 'Alanya Devlet Hastanesi', 'Özel Medicalpark', '']), sifrele(alerji ? 'Alerji durumunda 112 ve veli aranacak.' : '')];
    calis(`INSERT OR IGNORE INTO saglik_kartlari (student_membership_id, kan_grubu, gozluk, alerji, kronik, ilac, ozel_gereksinim, gecmis, diyet, hekim, hastane, acil_not, kaynak, guncelleyen_user_id, guncelleme) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      s.mid, g[0], g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8], g[9], g[10], 'okul', hemsire.uid, tamSaat(gunSec()));
    sayi.kart++;
    // Ölçümler: eylül ve kasım
    const boy0 = 110 + (s.sinif.match(/\d+/)?.[0] ?? 5) * 4.6 + rnd() * 8, kilo0 = boy0 * 0.19 + rnd() * 6;
    for (const [t, k] of [['2026-09-18', 0], ['2026-11-20', 1]]) {
      calis('INSERT INTO saglik_olcumleri (student_membership_id, tarih, boy_cm, kilo_kg, yazan_user_id, created_at) VALUES (?,?,?,?,?,?)', s.mid, t, Math.round((boy0 + k * 0.6) * 10) / 10, Math.round((kilo0 + k * 0.5) * 10) / 10, hemsire.uid, tamSaat(t));
      sayi.olcum++;
    }
    // Revir
    for (let n = demo ? 2 : olasilik(0.12) ? 1 + (olasilik(0.25) ? 1 : 0) : 0; n > 0; n--) {
      const [sik, mud, son] = sec(SIKAYET), t = gunSec();
      calis('INSERT INTO saglik_olaylari (student_membership_id, branch_id, tarih, saat, sikayet, mudahale, sonuc, veli_haber, yazan_user_id, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)', s.mid, o.id, t, saatSec(), sifrele(sik), sifrele(mud), son, son === 'sinifa' ? 0 : 1, hemsire.uid, tamSaat(t));
      sayi.olay++;
    }
  }
}

// ---------- Servis ----------
const MAHALLE = ['Çamlık Mah.', 'Cumhuriyet Mah.', 'Hacı Ömerli', 'Gazi Mah.', 'Sarılar', 'Çenger', 'Ilıca', 'Kızıldağ', 'Yenimahalle', 'Sahil Yolu'];
const ISIM = ['Kemal', 'Hasan', 'Recep', 'Ömer', 'Yusuf', 'Mustafa'];
const SOY = ['Aydın', 'Karaca', 'Demirtaş', 'Koç', 'Erdem', 'Yalçın'];
const HOSTES = ['Fatma', 'Zeynep', 'Havva', 'Emine'];
function servis(o, ogr) {
  const nServis = Math.max(2, Math.min(5, Math.round(ogr.length / 90)));
  const havuz = ogr.filter(s => hizliMid.has(s.mid) || olasilik(0.22));
  let sn = 0;
  for (let i = 1; i <= nServis; i++) {
    const r = calis('INSERT OR IGNORE INTO servisler (branch_id, ad, plaka, sofor_ad, sofor_tel, hostes_ad, hostes_tel, kapasite, notu, aktif, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      o.id, `Servis ${i}`, `07 ${sec(['ABK', 'DFM', 'NLK', 'TSE', 'ZRP'])} ${100 + Math.floor(rnd() * 899)}`, `${sec(ISIM)} ${sec(SOY)}`, sifrele(`05${sec(['32', '33', '05', '55'])}${String(1000000 + Math.floor(rnd() * 8999999))}`), `${sec(HOSTES)} ${sec(SOY)}`, sifrele(`05${sec(['32', '33', '05', '55'])}${String(1000000 + Math.floor(rnd() * 8999999))}`), 24 + Math.floor(rnd() * 12), 'Sabah 07:30 – akşam 16:30 çıkışı', 1, Date.now());
    const sid = Number(r.lastInsertRowid);
    if (!sid || r.changes === 0) continue;
    sayi.servis++;
    const durakSayisi = 4 + Math.floor(rnd() * 2), duraklar = [];
    for (let k = 1; k <= durakSayisi; k++) {
      const dk = 7 * 60 + 5 + k * 6;
      const d = calis('INSERT INTO servis_duraklari (servis_id, sira, ad, sabah_saat, aksam_saat) VALUES (?,?,?,?,?)', sid, k, sec(MAHALLE), `0${Math.floor(dk / 60)}:${String(dk % 60).padStart(2, '0')}`, `16:${String(30 + k * 5).padStart(2, '0')}`);
      duraklar.push(Number(d.lastInsertRowid));
    }
    for (let k = i - 1; k < havuz.length; k += nServis) {
      calis('INSERT OR IGNORE INTO servis_ogrenciler (student_membership_id, servis_id, durak_id, yon, created_at) VALUES (?,?,?,?,?)', havuz[k].mid, sid, sec(duraklar), sec(['cift', 'cift', 'cift', 'sabah', 'aksam']), Date.now());
      sayi.servisOgr++;
    }
    sn++;
  }
}

// ---------- Çalıştır ----------
const bos = t => bir(`SELECT COUNT(*) n FROM ${t}`).n === 0;
const yap = { r: bos('rehber_gorusmeleri'), s: bos('saglik_kartlari'), v: bos('servisler') };
db.exec('BEGIN');
try {
  for (const o of okullar) {
    const ogr = ogrenciler(o.id);
    if (!ogr.length) continue;
    if (yap.r) rehberlik(o, ogr);
    if (yap.s) saglik(o, ogr);
    if (yap.v) servis(o, ogr);
    console.log(' ', o.name, ogr.length, 'öğrenci');
  }
  db.exec('COMMIT');
  console.log('Bitti:', JSON.stringify(sayi));
} catch (e) {
  db.exec('ROLLBACK');
  console.error('HATA, geri alındı:', e);
  process.exit(1);
}
