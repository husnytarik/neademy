// Rehberlik, sağlık ve servis sayfalarının ortak yardımcıları
const $ = id => document.getElementById(id);

function mesaj(metin, tur = '') {
  const m = $('mesaj');
  m.textContent = metin;
  m.className = 'mesaj ' + tur;
  if (metin) m.scrollIntoView({ block: 'nearest' });
}

async function api(yol, govde) {
  const r = await fetch(yol, govde === undefined ? {} : {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(govde),
  });
  if (r.status === 401) { location.href = '/'; throw new Error('oturum'); }
  return { ok: r.ok, durum: r.status, veri: await r.json().catch(() => ({})) };
}

function el(tag, metin, sinif) {
  const e = document.createElement(tag);
  if (metin !== undefined && metin !== null) e.textContent = metin;
  if (sinif) e.className = sinif;
  return e;
}

let alanSayac = 0;
function alan(etiket, kontrol, genis) {
  kontrol.id = kontrol.id || 'a' + (++alanSayac);
  const l = el('label', etiket); l.htmlFor = kontrol.id;
  const kap = el('div', undefined, genis ? 'alan-genis' : '');
  kap.append(l, kontrol);
  return kap;
}

function girdi(tur, deger, ek = {}) {
  const i = el('input');
  i.type = tur;
  if (deger !== undefined && deger !== null) i.value = deger;
  Object.assign(i, ek);
  return i;
}

function metinAlan(deger, enCok, satir = 2) {
  const t = el('textarea');
  t.rows = satir; t.maxLength = enCok; t.value = deger || '';
  return t;
}

function secim(secenekler, deger) {
  const s = el('select');
  for (const [v, ad] of secenekler) s.append(Object.assign(el('option', ad), { value: String(v) }));
  if (deger !== undefined && deger !== null) s.value = String(deger);
  return s;
}

function bugunTarih() {
  return new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
}

function tarihYaz(t) {
  if (!t) return '';
  const [y, a, g] = String(t).slice(0, 10).split('-');
  return `${g}.${a}.${y}`;
}

function sorguAl(ad) { return new URLSearchParams(location.search).get(ad) || ''; }

function sekmeKur(kap, sekmeler, ac, baslangic) {
  kap.replaceChildren();
  kap.classList.remove('gizli');
  const dugmeler = {};
  const sec = ad => {
    for (const [k, b] of Object.entries(dugmeler)) b.setAttribute('aria-pressed', String(k === ad));
    ac(ad);
  };
  for (const [ad, baslik] of sekmeler) {
    const b = el('button', baslik); b.type = 'button';
    b.addEventListener('click', () => sec(ad));
    dugmeler[ad] = b; kap.append(b);
  }
  sec(baslangic || sekmeler[0][0]);
}

function bos(metin) { return el('p', metin, 'bos-not'); }

function onayla(metin) { return window.confirm(metin); }
