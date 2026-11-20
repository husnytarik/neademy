import { db } from './db.js';
import { sifrele, coz } from './gizli.js';
import {
  tamSayi, kisa, uzun, bugun, simdi, tarihGecerli, saatGecerli, Hata, hataYanit,
  okullarim, ogrenciAl, benimOgrencilerim, kapsamOgrencileri, yonetimYetkisi,
} from './okul-ortak.js';

// Öğrenci sağlık kartı: sağlık bilgileri veli ve okul tarafından doldurulur; revir kayıtları ve boy-kilo ölçümleri okulda tutulur.
// Serbest metin alanları (alerji, hastalık, ilaç, revir notları...) veritabanında şifreli durur.
// Görme kuralı: okul sağlık yetkilisi hepsini; sınıf/ders öğretmeni yalnızca uyarı alanlarını; veli çocuğunun kartını (ve düzenler);
// öğrenci kendi kartını (salt okunur) görür. Revir kayıtları öğretmene açılmaz.
db.exec(`
CREATE TABLE IF NOT EXISTS saglik_kartlari (
  student_membership_id INTEGER PRIMARY KEY REFERENCES memberships(id),
  kan_grubu            TEXT NOT NULL DEFAULT '',
  alerji               TEXT NOT NULL DEFAULT '',
  kronik               TEXT NOT NULL DEFAULT '',
  ilac                 TEXT NOT NULL DEFAULT '',
  ozel_gereksinim      TEXT NOT NULL DEFAULT '',
  gecmis               TEXT NOT NULL DEFAULT '',
  diyet                TEXT NOT NULL DEFAULT '',
  gozluk               INTEGER NOT NULL DEFAULT 0,
  hekim                TEXT NOT NULL DEFAULT '',
  hastane              TEXT NOT NULL DEFAULT '',
  acil_not             TEXT NOT NULL DEFAULT '',
  kaynak               TEXT NOT NULL DEFAULT 'okul',
  guncelleyen_user_id  INTEGER REFERENCES users(id),
  guncelleme           INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS saglik_olaylari (
  id                    INTEGER PRIMARY KEY,
  student_membership_id INTEGER NOT NULL REFERENCES memberships(id),
  branch_id             INTEGER NOT NULL REFERENCES branches(id),
  tarih                 TEXT NOT NULL,
  saat                  TEXT NOT NULL DEFAULT '',
  sikayet               TEXT NOT NULL,
  mudahale              TEXT NOT NULL DEFAULT '',
  sonuc                 TEXT NOT NULL DEFAULT 'sinifa',
  veli_haber            INTEGER NOT NULL DEFAULT 0,
  yazan_user_id         INTEGER NOT NULL REFERENCES users(id),
  created_at            INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS saglik_olay_ogrenci ON saglik_olaylari (student_membership_id, tarih);
CREATE TABLE IF NOT EXISTS saglik_olcumleri (
  id                    INTEGER PRIMARY KEY,
  student_membership_id INTEGER NOT NULL REFERENCES memberships(id),
  tarih                 TEXT NOT NULL,
  boy_cm                REAL,
  kilo_kg               REAL,
  yazan_user_id         INTEGER NOT NULL REFERENCES users(id),
  created_at            INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS saglik_olcum_ogrenci ON saglik_olcumleri (student_membership_id, tarih);
`);

export const KAN_GRUPLARI = ['', 'A Rh+', 'A Rh-', 'B Rh+', 'B Rh-', 'AB Rh+', 'AB Rh-', '0 Rh+', '0 Rh-'];
export const SONUCLAR = { sinifa: 'Sınıfa döndü', eve: 'Eve gönderildi', hastane: 'Hastaneye sevk', ilac: 'İlaç / müdahale sonrası dinlendi' };

// Kart alanları: [anahtar, sütun, enCok, şifreli]
const ALANLAR = [
  ['alerji', 'alerji', 400, true], ['kronik', 'kronik', 400, true], ['ilac', 'ilac', 400, true],
  ['ozelGereksinim', 'ozel_gereksinim', 400, true], ['gecmis', 'gecmis', 600, true], ['diyet', 'diyet', 300, true],
  ['hekim', 'hekim', 120, true], ['hastane', 'hastane', 120, false], ['acilNot', 'acil_not', 600, true],
];
// Sınıf/ders öğretmeninin görebildiği uyarı alanları
const UYARI_ALANLARI = ['alerji', 'kronik', 'ilac', 'ozelGereksinim', 'diyet', 'acilNot'];
const UYARI_ADLARI = { alerji: 'Alerji', kronik: 'Kronik hastalık', ilac: 'İlaç', ozelGereksinim: 'Özel gereksinim', diyet: 'Özel beslenme' };

const bosKart = () => ({ kanGrubu: '', gozluk: false, ...Object.fromEntries(ALANLAR.map(a => [a[0], ''])), kaynak: '', guncelleme: null });

function kartSatiri(r) {
  if (!r) return bosKart();
  const k = { kanGrubu: r.kan_grubu, gozluk: !!r.gozluk, kaynak: r.kaynak, guncelleme: r.guncelleme };
  for (const [anahtar, sutun, , sifreli] of ALANLAR) k[anahtar] = sifreli ? coz(r[sutun]) : r[sutun];
  return k;
}
const uyarilar = k => Object.entries(UYARI_ADLARI).filter(([a]) => k[a]).map(([, ad]) => ad);

function olaySatiri(r) {
  return { id: r.id, tarih: r.tarih, saat: r.saat, sikayet: coz(r.sikayet), mudahale: coz(r.mudahale), sonuc: r.sonuc, sonucAd: SONUCLAR[r.sonuc] || '', veliHaber: !!r.veli_haber, yazan: r.yazan || '' };
}
const olcumSatiri = r => ({ id: r.id, tarih: r.tarih, boy: r.boy_cm, kilo: r.kilo_kg, bki: r.boy_cm && r.kilo_kg ? Math.round(r.kilo_kg / ((r.boy_cm / 100) ** 2) * 10) / 10 : null });

// Öğretmenin ders verdiği ya da sınıf öğretmeni olduğu sınıfların öğrencileri
function ogretmenOgrencileri(o) {
  return db.prepare(`SELECT m.id, m.user_id AS userId, m.branch_id AS subeId, u.full_name AS ad, cs.class_id AS sinifId, c.name AS sinif, b.name AS okul
    FROM memberships m JOIN users u ON u.id = m.user_id
    JOIN class_students cs ON cs.student_membership_id = m.id JOIN classes c ON c.id = cs.class_id
    LEFT JOIN branches b ON b.id = m.branch_id
    WHERE m.role = 'ogrenci' AND m.status = 'aktif'
      AND (c.homeroom_membership_id = ? OR EXISTS (SELECT 1 FROM assignments a WHERE a.class_id = c.id AND a.teacher_membership_id = ?))
    ORDER BY c.name, u.full_name`).all(o.membership_id, o.membership_id);
}

function kartKaydet(ogrenciId, g, aktorUserId, kaynak) {
  const kan = KAN_GRUPLARI.includes(g.kanGrubu ?? '') ? (g.kanGrubu ?? '') : '';
  const deger = {};
  for (const [anahtar, sutun, enCok, sifreli] of ALANLAR) {
    const v = anahtar === 'hastane' || anahtar === 'hekim' ? kisa(g[anahtar], enCok) : uzun(g[anahtar], enCok);
    deger[sutun] = sifreli ? sifrele(v) : v;
  }
  const sut = Object.keys(deger);
  db.prepare(`INSERT INTO saglik_kartlari (student_membership_id, kan_grubu, gozluk, ${sut.join(', ')}, kaynak, guncelleyen_user_id, guncelleme)
    VALUES (?, ?, ?, ${sut.map(() => '?').join(', ')}, ?, ?, ?)
    ON CONFLICT (student_membership_id) DO UPDATE SET kan_grubu = excluded.kan_grubu, gozluk = excluded.gozluk,
      ${sut.map(s => `${s} = excluded.${s}`).join(', ')}, kaynak = excluded.kaynak, guncelleyen_user_id = excluded.guncelleyen_user_id, guncelleme = excluded.guncelleme`)
    .run(ogrenciId, kan, g.gozluk ? 1 : 0, ...sut.map(s => deger[s]), kaynak, aktorUserId, Date.now());
}

export async function saglikApi({ req, res, url, o, json, govde, denetle }) {
  const yol = url.pathname;
  if (!yol.startsWith('/api/saglik/')) return false;
  const yonetici = yonetimYetkisi(o, 'saglik');
  const ogretmen = o.role === 'ogretmen';
  if (o.role === 'yonetim' && !yonetici) { json(res, 403, { hata: 'Bu işlem için yetkiniz yok' }); return true; }
  try {
    // ---- Sayfa bağlamı ----
    if (req.method === 'GET' && yol === '/api/saglik/baglam') {
      const rol = yonetici ? 'yonetim' : o.role;
      const sonuc = { rol, kanGruplari: KAN_GRUPLARI.filter(Boolean), sonuclar: SONUCLAR };
      if (yonetici) {
        sonuc.okullar = okullarim(o);
        sonuc.siniflar = db.prepare('SELECT id, name AS ad, branch_id AS okulId FROM classes ORDER BY name').all().filter(c => sonuc.okullar.some(b => b.id === c.okulId));
      }
      if (o.role === 'veli' || o.role === 'ogrenci') sonuc.ogrenciler = benimOgrencilerim(o).map(r => ({ id: r.id, ad: r.ad, sinif: r.sinif }));
      return json(res, 200, sonuc), true;
    }

    // ---- Öğrenci listesi (okul sağlık yetkilisi: kapsamdaki okullar; öğretmen: kendi öğrencileri) ----
    if (req.method === 'GET' && yol === '/api/saglik/liste') {
      if (!yonetici && !ogretmen) throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const ogrenciler = yonetici
        ? kapsamOgrencileri(o, { okul: url.searchParams.get('okul'), sinif: url.searchParams.get('sinif'), ara: url.searchParams.get('ara') })
        : ogretmenOgrencileri(o);
      const idler = ogrenciler.map(r => r.id);
      const kartlar = new Map();
      for (let i = 0; i < idler.length; i += 400) {
        const parca = idler.slice(i, i + 400);
        for (const r of db.prepare(`SELECT * FROM saglik_kartlari WHERE student_membership_id IN (${parca.map(() => '?').join(',')})`).all(...parca)) kartlar.set(r.student_membership_id, r);
      }
      const sonOlay = new Map();
      if (yonetici) for (const r of db.prepare('SELECT student_membership_id AS id, MAX(tarih) AS tarih, COUNT(*) AS n FROM saglik_olaylari GROUP BY student_membership_id').all()) sonOlay.set(r.id, r);
      const filtre = url.searchParams.get('filtre') || 'tum';
      let satirlar = ogrenciler.map(r => {
        const kart = kartlar.has(r.id) ? kartSatiri(kartlar.get(r.id)) : null;
        const u = kart ? uyarilar(kart) : [];
        return { id: r.id, ad: r.ad, sinif: r.sinif || '', okul: r.okul || '', okulId: r.subeId, kartVar: !!kart, kanGrubu: kart?.kanGrubu || '', uyarilar: u,
          kaynak: kart?.kaynak || '', guncelleme: kart?.guncelleme || null, olaySayisi: sonOlay.get(r.id)?.n || 0, sonOlay: sonOlay.get(r.id)?.tarih || '' };
      });
      const toplam = { ogrenci: satirlar.length, kartsiz: satirlar.filter(s => !s.kartVar).length, uyarili: satirlar.filter(s => s.uyarilar.length).length };
      if (filtre === 'uyari' || ogretmen) satirlar = satirlar.filter(s => s.uyarilar.length);
      else if (filtre === 'eksik') satirlar = satirlar.filter(s => !s.kartVar);
      else if (filtre === 'veli') satirlar = satirlar.filter(s => s.kaynak === 'veli');
      return json(res, 200, { ogrenciler: satirlar, toplam }), true;
    }

    // ---- Son revir kayıtları (okul sağlık yetkilisi) ----
    if (req.method === 'GET' && yol === '/api/saglik/olaylar') {
      if (!yonetici) throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const kapsamIdleri = new Set(okullarim(o).map(b => b.id));
      const gun = tamSayi(url.searchParams.get('gun'), 1, 365) || 30;
      const ilk = new Date(Date.now() - gun * 86400000).toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
      const okul = tamSayi(url.searchParams.get('okul'));
      const satirlar = db.prepare(`SELECT e.*, u.full_name AS ogrenci, c.name AS sinif, y.full_name AS yazan, b.name AS okul
        FROM saglik_olaylari e JOIN memberships m ON m.id = e.student_membership_id JOIN users u ON u.id = m.user_id
        JOIN users y ON y.id = e.yazan_user_id JOIN branches b ON b.id = e.branch_id
        LEFT JOIN class_students cs ON cs.student_membership_id = m.id LEFT JOIN classes c ON c.id = cs.class_id
        WHERE e.tarih >= ? ORDER BY e.tarih DESC, e.saat DESC, e.id DESC LIMIT 500`).all(ilk)
        .filter(r => kapsamIdleri.has(r.branch_id) && (!okul || r.branch_id === okul));
      return json(res, 200, { olaylar: satirlar.map(r => ({ ...olaySatiri(r), ogrenciId: r.student_membership_id, ogrenci: r.ogrenci, sinif: r.sinif || '', okul: r.okul })) }), true;
    }

    // ---- Tek öğrencinin kartı ----
    if (req.method === 'GET' && yol === '/api/saglik/ogrenci') {
      const ogr = ogrenciAl(o, url.searchParams.get('id'));
      const kartSatir = db.prepare('SELECT * FROM saglik_kartlari WHERE student_membership_id = ?').get(ogr.id);
      let kart = kartSatiri(kartSatir);
      const sonuc = { ogrenci: { id: ogr.id, ad: ogr.ad, sinif: ogr.sinif || '', okul: ogr.okul || '' }, kartVar: !!kartSatir };
      if (ogr.iliski === 'ogretmen') {
        kart = Object.fromEntries(['kanGrubu', 'gozluk', 'guncelleme', ...UYARI_ALANLARI].map(a => [a, kart[a]]));
        Object.assign(sonuc, { gorunum: 'uyari', duzenle: false });
      } else {
        Object.assign(sonuc, { gorunum: ogr.iliski, duzenle: ogr.iliski === 'yonetim' || ogr.iliski === 'veli' });
        sonuc.olcumler = db.prepare('SELECT * FROM saglik_olcumleri WHERE student_membership_id = ? ORDER BY tarih DESC, id DESC LIMIT 60').all(ogr.id).map(olcumSatiri);
        if (ogr.iliski !== 'ogrenci') {
          sonuc.olaylar = db.prepare(`SELECT e.*, y.full_name AS yazan FROM saglik_olaylari e JOIN users y ON y.id = e.yazan_user_id
            WHERE e.student_membership_id = ? ORDER BY e.tarih DESC, e.saat DESC, e.id DESC LIMIT 100`).all(ogr.id).map(olaySatiri);
          if (ogr.iliski === 'veli') for (const x of sonuc.olaylar) x.yazan = '';
        }
        sonuc.olcumDuzenle = ogr.iliski === 'yonetim';
      }
      sonuc.kart = kart;
      return json(res, 200, sonuc), true;
    }

    // ---- Kartı kaydet: okul sağlık yetkilisi ya da çocuğunun velisi ----
    if (req.method === 'POST' && yol === '/api/saglik/kart') {
      const g = await govde(req);
      const ogr = ogrenciAl(o, g.ogrenciId);
      if (ogr.iliski !== 'yonetim' && ogr.iliski !== 'veli') throw new Hata(403, 'Bu işlem için yetkiniz yok');
      kartKaydet(ogr.id, g, o.user_id, ogr.iliski === 'veli' ? 'veli' : 'okul');
      denetle(o.user_id, 'saglik.kart', { ogrenciId: ogr.id, kaynak: ogr.iliski });
      return json(res, 200, { tamam: true }), true;
    }

    // ---- Revir kaydı ----
    if (req.method === 'POST' && yol === '/api/saglik/olay') {
      const g = await govde(req);
      const ogr = ogrenciAl(o, g.ogrenciId);
      if (ogr.iliski !== 'yonetim') throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const tarih = g.tarih || bugun();
      const saat = g.saat === undefined || g.saat === '' ? simdi() : g.saat;
      const sikayet = uzun(g.sikayet, 400);
      if (!tarihGecerli(tarih) || tarih > bugun()) throw new Hata(400, 'Tarih geçersiz');
      if (!saatGecerli(saat)) throw new Hata(400, 'Saat geçersiz');
      if (sikayet.length < 2) throw new Hata(400, 'Şikâyeti yazın');
      const sonuc = Object.hasOwn(SONUCLAR, g.sonuc) ? g.sonuc : 'sinifa';
      const r = db.prepare(`INSERT INTO saglik_olaylari (student_membership_id, branch_id, tarih, saat, sikayet, mudahale, sonuc, veli_haber, yazan_user_id, created_at)
        VALUES (?,?,?,?,?,?,?,?,?,?)`).run(ogr.id, ogr.subeId, tarih, saat, sifrele(sikayet), sifrele(uzun(g.mudahale, 400)), sonuc, g.veliHaber ? 1 : 0, o.user_id, Date.now());
      denetle(o.user_id, 'saglik.olay', { ogrenciId: ogr.id, olayId: Number(r.lastInsertRowid) });
      return json(res, 200, { tamam: true, id: Number(r.lastInsertRowid) }), true;
    }
    if (req.method === 'POST' && yol === '/api/saglik/olay-sil') {
      const g = await govde(req);
      const e = db.prepare('SELECT * FROM saglik_olaylari WHERE id = ?').get(tamSayi(g.id) || 0);
      const ogr = e && ogrenciAl(o, e.student_membership_id);
      if (!e || ogr.iliski !== 'yonetim') throw new Hata(404, 'Kayıt bulunamadı');
      db.prepare('DELETE FROM saglik_olaylari WHERE id = ?').run(e.id);
      denetle(o.user_id, 'saglik.olay-sil', { ogrenciId: e.student_membership_id, olayId: e.id });
      return json(res, 200, { tamam: true }), true;
    }

    // ---- Boy-kilo ölçümü ----
    if (req.method === 'POST' && yol === '/api/saglik/olcum') {
      const g = await govde(req);
      const ogr = ogrenciAl(o, g.ogrenciId);
      if (ogr.iliski !== 'yonetim') throw new Hata(403, 'Bu işlem için yetkiniz yok');
      const tarih = g.tarih || bugun();
      const boy = g.boy === '' || g.boy == null ? null : Number(String(g.boy).replace(',', '.'));
      const kilo = g.kilo === '' || g.kilo == null ? null : Number(String(g.kilo).replace(',', '.'));
      if (!tarihGecerli(tarih) || tarih > bugun()) throw new Hata(400, 'Tarih geçersiz');
      if (boy === null && kilo === null) throw new Hata(400, 'Boy ya da kilo girin');
      if (boy !== null && !(boy >= 40 && boy <= 230)) throw new Hata(400, 'Boy 40-230 cm arasında olmalı');
      if (kilo !== null && !(kilo >= 2 && kilo <= 250)) throw new Hata(400, 'Kilo 2-250 kg arasında olmalı');
      db.prepare('INSERT INTO saglik_olcumleri (student_membership_id, tarih, boy_cm, kilo_kg, yazan_user_id, created_at) VALUES (?,?,?,?,?,?)')
        .run(ogr.id, tarih, boy, kilo, o.user_id, Date.now());
      denetle(o.user_id, 'saglik.olcum', { ogrenciId: ogr.id });
      return json(res, 200, { tamam: true }), true;
    }
    if (req.method === 'POST' && yol === '/api/saglik/olcum-sil') {
      const g = await govde(req);
      const e = db.prepare('SELECT * FROM saglik_olcumleri WHERE id = ?').get(tamSayi(g.id) || 0);
      const ogr = e && ogrenciAl(o, e.student_membership_id);
      if (!e || ogr.iliski !== 'yonetim') throw new Hata(404, 'Kayıt bulunamadı');
      db.prepare('DELETE FROM saglik_olcumleri WHERE id = ?').run(e.id);
      return json(res, 200, { tamam: true }), true;
    }
  } catch (e) { return hataYanit(res, json, e); }
  return false;
}
