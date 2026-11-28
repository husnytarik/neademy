// Okulumuz: kurum ve okulların tanıtım sayfası (öğrenci, veli, öğretmen, yönetim okur)
const SITE = /^https?:\/\/(www\.)?/;

function satir(simge, ad, deger, adres) {
  const a = el('a', undefined, 'bag-satir');
  a.href = adres; a.target = '_blank'; a.rel = 'noopener';
  a.style.cssText = 'display:flex;gap:12px;align-items:center;padding:10px 2px;border-bottom:1px solid var(--cizgi,#e5e5e5);text-decoration:none;color:inherit';
  const s = el('span', simge); s.style.fontSize = '20px';
  const m = el('span'); m.style.flex = '1';
  const k = el('small', ad); k.style.cssText = 'display:block;opacity:.65';
  m.append(k, document.createTextNode(deger));
  a.append(s, m, el('span', '↗'));
  return a;
}

function baglantilar(v, x, kap) {
  const sosyal = x.sosyal || {};
  const simge = { instagram: '📷', facebook: '👍', youtube: '▶️', tiktok: '🎵', linkedin: '💼' };
  const izle = [];
  if (x.web) izle.push(satir('🌐', 'Web sitesi', x.web.replace(SITE, ''), /^https?:/.test(x.web) ? x.web : 'https://' + x.web));
  for (const a of v.sosyalAlanlar) if (sosyal[a.kod]) izle.push(satir(simge[a.kod] || '@', a.ad, String(sosyal[a.kod]).replace(SITE, ''), sosyal[a.kod]));
  const il = [];
  if (x.telefon) il.push(satir('📞', 'Telefon', x.telefon, 'tel:' + x.telefon.replace(/\s/g, '')));
  if (x.eposta) il.push(satir('✉️', 'E-posta', x.eposta, 'mailto:' + x.eposta));
  if (x.adres) il.push(satir('📍', 'Adres', x.adres, 'https://maps.google.com/?q=' + encodeURIComponent(x.adres)));
  if (izle.length) kap.append(el('h2', 'Bizi takip edin', 'baslik2'), ...izle);
  if (il.length) kap.append(el('h2', 'İletişim', 'baslik2'), ...il);
}

function ust(ad, alt, logoYol) {
  const k = el('div'); k.style.cssText = 'display:flex;gap:14px;align-items:center;margin:8px 0';
  const l = el('div', (ad || '?').trim().charAt(0).toUpperCase());
  l.style.cssText = 'width:64px;height:64px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:26px;overflow:hidden;background:rgba(127,127,127,.15);flex:none';
  if (logoYol) { const i = new Image(); i.src = logoYol; i.alt = ''; i.style.cssText = 'width:100%;height:100%;object-fit:contain'; i.onload = () => l.replaceChildren(i); }
  const m = el('div'); m.append(el('h2', ad)); if (alt) m.append(el('p', alt, 'kucuk'));
  k.append(l, m);
  return k;
}

function okulBolumu(v, o, kap) {
  const logo = o.logo ? `/api/okul-logo?id=${o.id}&v=${o.logo}` : '';
  kap.append(ust(o.ad, [o.tur, o.kampus].filter(Boolean).join(' · '), logo));
  kap.append(el('p', `${o.ogrenci} öğrenci · ${o.ogretmen} öğretmen`, 'kucuk'));
  if (o.aciklama) kap.append(el('h2', 'Okulumuz hakkında', 'baslik2'), el('p', o.aciklama));
  const yon = [...o.yoneticiler.filter(y => y.gorev === 'mudur'), ...o.yoneticiler.filter(y => y.gorev !== 'mudur')];
  if (yon.length) {
    kap.append(el('h2', 'Okul yönetimi', 'baslik2'));
    for (const y of yon) kap.append(el('p', `${y.ad} — ${v.gorevler[y.gorev] || y.gorev}`));
  }
  baglantilar(v, o, kap);
}

async function basla() {
  const r = await api('/api/okulum');
  if (!r.ok) return mesaj(r.veri.hata || 'Sayfa alınamadı', 'hata');
  const v = r.veri, k = v.kurum, icerik = $('icerik');
  icerik.replaceChildren(ust(k.ad, k.kisaAd, v.logo ? '/api/kurum-logo?v=' + v.logo : ''));
  if (k.aciklama) icerik.append(el('h2', 'Biz kimiz', 'baslik2'), ...k.aciklama.split(/\n+/).map(p => el('p', p)));
  baglantilar(v, k, icerik);
  if (v.okullar.length === 1) { icerik.append(document.createElement('hr')); okulBolumu(v, v.okullar[0], icerik); }
  else if (v.okullar.length > 1) {
    icerik.append(el('h2', 'Okullarımız', 'baslik2'));
    for (const o of v.okullar) {
      const d = document.createElement('details'); d.style.cssText = 'padding:8px 0;border-bottom:1px solid var(--cizgi,#e5e5e5)';
      const s = document.createElement('summary'); s.textContent = o.ad + ' · ' + [o.tur, o.kampus].filter(Boolean).join(' · '); s.style.cursor = 'pointer';
      d.append(s); okulBolumu(v, o, d); icerik.append(d);
    }
  }
}
basla();
