import { db } from './db.js';

// Okul kapsamı: yönetimin hangi okullardaki veriyi görüp değiştirebileceği.
//  - Kurum yönetimi (memberships.gorev = 'kurum'): hepsi  → null
//  - Okul yönetimi: yalnızca aktif yönetim üyeliği olduğu okullar → [okulId, ...]
//  - Yönetim dışı roller bu yardımcıyla sınırlanmaz (kendi kuralları vardır) → null
export function okulKapsami(o) {
  if (o.role !== 'yonetim' || o.gorev === 'kurum') return null;
  return db.prepare("SELECT DISTINCT branch_id AS id FROM memberships WHERE user_id = ? AND role = 'yonetim' AND status = 'aktif' AND branch_id IS NOT NULL")
    .all(o.user_id).map(r => r.id);
}
export const kapsamdaMi = (kapsam, subeId) => !kapsam || kapsam.includes(subeId);
// Satır listesini kapsama göre süzer: alan okulu gösteren anahtar
export const kapsamSuz = (kapsam, satirlar, alan = 'subeId') => (kapsam ? satirlar.filter(r => kapsam.includes(r[alan])) : satirlar);
