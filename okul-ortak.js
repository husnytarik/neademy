import { db } from './db.js';
import { okulKapsami, kapsamdaMi } from './kapsam.js';
import { ogrenciErisimi } from './ogrenci.js';
import { yetkiVar } from './yetki.js';

// Rehberlik, sağlık ve servis modüllerinin ortak yardımcıları: girdi temizleme, okul kapsamı ve öğrenciye erişim kuralı.

export const tamSayi = (v, min = 1, max = 1e9) => {
  const n = Number(v);
  return Number.isInteger(n) && n >= min && n <= max ? n : null;
};
export const kisa = (v, enCok) => String(v ?? '').replace(/\s+/g, ' ').trim().slice(0, enCok);
export const uzun = (v, enCok) => String(v ?? '').replace(/\r\n/g, '\n').replace(/[ \t]+/g, ' ').trim().slice(0, enCok);
export const bugun = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
export const simdi = () => new Date().toLocaleTimeString('sv-SE', { timeZone: 'Europe/Istanbul', hour: '2-digit', minute: '2-digit' });
export const tarihGecerli = t => /^\d{4}-\d{2}-\d{2}$/.test(t) && !Number.isNaN(Date.parse(t));
export const saatGecerli = t => /^([01]\d|2[0-3]):[0-5]\d$/.test(t);

export class Hata extends Error {
  constructor(kod, mesaj) { super(mesaj); this.kod = kod; }
}

// Yönetimin görebildiği okullar (kurum yönetimi: hepsi)
export function okullarim(o) {
  const kapsam = okulKapsami(o);
  const hepsi = db.prepare('SELECT id, name AS ad FROM branches ORDER BY id').all();
  return kapsam ? hepsi.filter(b => kapsam.includes(b.id)) : hepsi;
}

// Yazma işleminde okul: istekte verilen okul kapsamda olmalı; verilmezse yönetimin kendi üyeliğinin okulu
export function okulSec(o, istenen) {
  const kapsam = okulKapsami(o);
  const varsayilan = db.prepare('SELECT branch_id FROM memberships WHERE id = ?').get(o.membership_id)?.branch_id;
  const id = istenen === undefined || istenen === null || istenen === '' ? varsayilan : tamSayi(istenen);
  if (!id || !db.prepare('SELECT 1 FROM branches WHERE id = ?').get(id)) throw new Hata(400, 'Okul seçin');
  if (!kapsamdaMi(kapsam, id)) throw new Hata(403, 'Bu okul için yetkiniz yok');
  return id;
}

const OGRENCI_SQL = `SELECT m.id, m.user_id AS userId, m.branch_id AS subeId, m.status AS durum, u.full_name AS ad,
    cs.class_id AS sinifId, c.name AS sinif, b.name AS okul
  FROM memberships m JOIN users u ON u.id = m.user_id
  LEFT JOIN class_students cs ON cs.student_membership_id = m.id LEFT JOIN classes c ON c.id = cs.class_id
  LEFT JOIN branches b ON b.id = m.branch_id
  WHERE m.role = 'ogrenci'`;

export const ogrenciSatiri = id => db.prepare(OGRENCI_SQL + ' AND m.id = ?').get(id);

// Oturumdaki kişi bu öğrenciye hangi sıfatla ulaşıyor? 'yonetim' | 'ogretmen' | 'veli' | 'ogrenci' | null
// Yönetim ve öğretmen kuralı öğrenci dosyasıyla aynıdır (okul kapsamı, sınıf/ders öğretmenliği).
export function ogrenciIliskisi(o, id) {
  if (!tamSayi(id)) return null;
  if (o.role === 'ogrenci') return o.membership_id === id ? 'ogrenci' : null;
  if (o.role === 'veli') return db.prepare('SELECT 1 FROM guardians WHERE parent_membership_id = ? AND student_membership_id = ?').get(o.membership_id, id) ? 'veli' : null;
  if (o.role === 'yonetim' || o.role === 'ogretmen') return ogrenciErisimi(o, id) ? o.role : null;
  return null;
}

// İlgili öğrenciyi ve sıfatı döner; erişim yoksa 404 (varlığı sızdırmaz)
export function ogrenciAl(o, id) {
  const iliski = ogrenciIliskisi(o, tamSayi(id));
  const ogr = iliski && ogrenciSatiri(Number(id));
  if (!ogr) throw new Hata(404, 'Öğrenci bulunamadı');
  return { ...ogr, iliski };
}

// Veli: çocukları; öğrenci: kendisi
export function benimOgrencilerim(o) {
  if (o.role === 'ogrenci') return db.prepare(OGRENCI_SQL + ' AND m.id = ?').all(o.membership_id);
  if (o.role !== 'veli') return [];
  return db.prepare(OGRENCI_SQL + ` AND m.status = 'aktif' AND m.id IN (SELECT student_membership_id FROM guardians WHERE parent_membership_id = ?) ORDER BY u.full_name`).all(o.membership_id);
}

// Yönetimin kapsamındaki okulların öğrencileri (süzgeçlerle)
export function kapsamOgrencileri(o, { okul, sinif, ara } = {}) {
  const kapsam = okulKapsami(o);
  let sql = OGRENCI_SQL + " AND m.status = 'aktif'";
  const p = [];
  if (kapsam) { if (!kapsam.length) return []; sql += ` AND m.branch_id IN (${kapsam.map(() => '?').join(',')})`; p.push(...kapsam); }
  if (tamSayi(okul)) { sql += ' AND m.branch_id = ?'; p.push(Number(okul)); }
  if (tamSayi(sinif)) { sql += ' AND cs.class_id = ?'; p.push(Number(sinif)); }
  const q = kisa(ara, 60).toLocaleLowerCase('tr');
  const sonuc = db.prepare(sql + ' ORDER BY c.name, u.full_name').all(...p);
  return q ? sonuc.filter(r => r.ad.toLocaleLowerCase('tr').includes(q)) : sonuc;
}

export const yonetimYetkisi = (o, kod) => o.role === 'yonetim' && yetkiVar(o, kod);

// Modül işleyicilerinde hata sınıfını yanıta çevirir
export function hataYanit(res, json, e) {
  if (e instanceof Hata) { json(res, e.kod, { hata: e.message }); return true; }
  throw e;
}

export function islem(fn) {
  db.exec('BEGIN');
  try { const s = fn(); db.exec('COMMIT'); return s; } catch (e) { db.exec('ROLLBACK'); throw e; }
}
