const $ = id => document.getElementById(id);

let veri = null;     // /api/zumre/baskanlar/liste yanıtı
let duzenle;         // düzenlenen toplantı (null: yeni, undefined: form kapalı)
let kararId = null;  // karar yazılan toplantı

function el(tag, metin, sinif) {
  const e = document.createElement(tag);
  if (metin !== undefined) e.textContent = metin;
  if (sinif) e.className = sinif;
  return e;
}

function mesaj(metin, tur = '') {
  $('mesaj').textContent = metin;
  $('mesaj').className = 'mesaj ' + tur;
}

async function api(yol, govde) {
  const r = await fetch(yol, govde === undefined ? { cache: 'no-store' } : {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(govde),
  });
  if (r.status === 401) { location.href = '/'; throw new Error('oturum'); }
  return { ok: r.ok, veri: await r.json().catch(() => ({})) };
}

function dugme(metin, tikla, sinif = 'ikincil kucuk') {
  const b = el('button', metin, sinif);
  b.type = 'button';
  b.addEventListener('click', tikla);
  return b;
}

const AY = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
const GUN = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];
const uzunTarih = t => { const [, a, g] = t.split('-'); return `${Number(g)} ${AY[Number(a) - 1]} ${GUN[new Date(t + 'T00:00:00Z').getUTCDay()]}`; };
const zamanYaz = ms => new Date(ms).toLocaleString('tr-TR', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });

// Okul seçimi: türe göre gruplanmış onay kutuları
function okulSecimi(secili) {
  const kap = el('div', undefined, 'zm-okullar');
  const grup = new Map();
  for (const o of veri.okullar) {
    const ad = o.tur || 'Diğer';
    if (!grup.has(ad)) grup.set(ad, []);
    grup.get(ad).push(o);
  }
  const kutular = [];
  for (const [tur, liste] of grup) {
    const g = el('div', undefined, 'zm-okul-grup');
    const ust = el('div', undefined, 'zm-okul-ust');
    ust.append(el('strong', tur));
    const hepsi = dugme('Tümü', () => {
      const hepsiSecili = liste.every(o => o.kutu.checked);
      for (const o of liste) o.kutu.checked = !hepsiSecili;
    }, 'ikincil kucuk');
    if (liste.length > 1) ust.append(hepsi);
    g.append(ust);
    for (const o of liste) {
      const l = el('label', undefined, 'zm-okul');
      const k = el('input'); k.type = 'checkbox'; k.value = o.id; k.checked = (secili || []).includes(o.id);
      o.kutu = k; kutular.push(k);
      const ad = el('span'); ad.append(el('b', o.ad), el('small', o.kampus || ''));
      l.append(k, ad);
      g.append(l);
    }
    kap.append(g);
  }
  if (!veri.okullar.length) kap.append(el('p', 'Seçilebilir okul yok.', 'alt'));
  return { kap, secilen: () => kutular.filter(k => k.checked).map(k => Number(k.value)) };
}

function form() {
  const t = duzenle || { baslik: 'Zümre başkanları toplantısı', okulIds: veri.varsayilan, tarih: '', saat: '15:00', yer: '', gundem: '' };
  const f = el('form', undefined, 'zm-form');
  let sayac = 0;
  const alan = (etiket, girdi) => {
    const d = el('div');
    girdi.id = 'bf' + sayac++;
    const l = el('label', etiket);
    l.htmlFor = girdi.id;
    d.append(l, girdi);
    return d;
  };
  const okul = okulSecimi(t.okulIds);
  const baslik = el('input'); baslik.maxLength = 80; baslik.value = t.baslik;
  const tarih = el('input'); tarih.type = 'date'; tarih.required = true; tarih.value = t.tarih;
  const saat = el('input'); saat.type = 'time'; saat.required = true; saat.value = t.saat;
  const yer = el('input'); yer.maxLength = 60; yer.value = t.yer; yer.placeholder = 'Örn. Toplantı salonu';
  const gundem = el('textarea'); gundem.maxLength = 500; gundem.value = t.gundem; gundem.placeholder = 'Gündem maddeleri (isteğe bağlı)';
  const s1 = el('div', undefined, 'form-satir'); s1.append(alan('Başlık', baslik));
  const okulKap = el('div'); okulKap.append(el('p', 'Katılan okullar (birden fazla seçilebilir)', 'prg-etiket'), okul.kap);
  const s2 = el('div', undefined, 'form-satir'); s2.append(alan('Tarih', tarih), alan('Saat', saat), alan('Yer', yer));
  const d = el('div', undefined, 'zm-dugme');
  const kaydet = el('button', duzenle ? 'Kaydet' : 'Toplantıyı ekle', 'birincil kucuk'); kaydet.type = 'submit';
  d.append(kaydet, dugme('Vazgeç', () => { duzenle = undefined; ciz(); }));
  f.append(s1, okulKap, s2, alan('Gündem', gundem), d);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    if (!okul.secilen().length) return mesaj('En az bir okul seçin', 'hata');
    const r = await api('/api/zumre/baskanlar/kaydet', { id: duzenle?.id, okulIds: okul.secilen(), baslik: baslik.value, tarih: tarih.value, saat: saat.value, yer: yer.value, gundem: gundem.value });
    if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj('Toplantı kaydedildi.', 'basari');
    duzenle = undefined;
    yukle();
  });
  return f;
}

function kararFormu(t) {
  const f = el('form', undefined, 'zm-form');
  const m = el('textarea'); m.maxLength = 2000; m.value = t.karar; m.placeholder = 'Toplantıda alınan kararlar…';
  m.setAttribute('aria-label', 'Alınan kararlar');
  const d = el('div', undefined, 'zm-dugme');
  const g = el('button', 'Kaydet', 'birincil kucuk'); g.type = 'submit';
  d.append(g, dugme('Vazgeç', () => { kararId = null; ciz(); }));
  f.append(m, d);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    const r = await api('/api/zumre/baskanlar/karar', { id: t.id, karar: m.value });
    if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj('Karar kaydedildi.', 'basari');
    kararId = null;
    yukle();
  });
  return f;
}

function satir(t) {
  const s = el('div', undefined, 'zm-yazi');
  const ust = el('div', undefined, 'zm-yazi-ust');
  ust.append(el('strong', t.baslik), el('small', `${uzunTarih(t.tarih)} ${t.saat}${t.yer ? ' · ' + t.yer : ''}`));
  s.append(ust, el('small', t.okullar.length > 1 ? `${t.okullar.length} okul: ${t.okul}` : t.okul));
  if (t.gundem) s.append(el('p', t.gundem, 'zm-gundem'));
  if (kararId === t.id) s.append(kararFormu(t));
  else if (t.karar) {
    s.append(el('strong', 'Alınan kararlar'), el('p', t.karar, 'zm-gundem'), el('small', `${t.kararYazan || ''} · ${zamanYaz(t.kararZamani)}`));
  } else if (t.basladi) s.append(el('p', 'Karar henüz yazılmadı.', 'alt'));
  if (kararId !== t.id) {
    const d = el('div', undefined, 'zm-dugme');
    if (t.basladi) d.append(dugme(t.karar ? 'Kararı düzenle' : 'Toplantıyı bitir', () => { kararId = t.id; ciz(); }, t.karar ? 'ikincil kucuk' : 'birincil kucuk'));
    if (t.duzenleyebilir) d.append(dugme('Düzenle', () => { duzenle = t; ciz(); window.scrollTo(0, 0); }), dugme('Sil', async () => {
      if (!confirm(`"${t.baslik}" toplantısı ve varsa kararı silinsin mi?`)) return;
      const r = await api('/api/zumre/baskanlar/sil', { id: t.id });
      if (!r.ok) return mesaj(r.veri.hata || 'Silinemedi', 'hata');
      yukle();
    }, 'ikincil kucuk tehlike'));
    if (d.children.length) s.append(d);
  }
  return s;
}

function ciz() {
  const k = $('icerik');
  k.replaceChildren();
  if (!veri) return;
  if (duzenle !== undefined) k.append(el('h2', duzenle ? 'Toplantıyı düzenle' : 'Yeni toplantı', 'baslik3'), form());
  else { const sat = el('div', undefined, 'zm-ekle-satir'); sat.append(dugme('+ Toplantı ekle', () => { duzenle = null; ciz(); }, 'birincil')); k.append(sat); }
  const gelecek = veri.toplantilar.filter(t => !t.basladi).reverse();
  const gecmis = veri.toplantilar.filter(t => t.basladi);
  if (!veri.toplantilar.length) k.append(el('p', 'Henüz toplantı yok. Toplantıyı ekleyin; o okulun zümre başkanlarının paneline hatırlatma düşer.', 'alt'));
  if (gelecek.length) { k.append(el('h2', 'Yaklaşan toplantılar', 'baslik3')); for (const t of gelecek) k.append(satir(t)); }
  if (gecmis.length) { k.append(el('h2', 'Yapılan toplantılar', 'baslik3')); for (const t of gecmis) k.append(satir(t)); }
}

async function yukle() {
  const r = await api('/api/zumre/baskanlar/liste');
  if (!r.ok) return mesaj(r.veri.hata || 'Toplantılar yüklenemedi', 'hata');
  veri = r.veri;
  ciz();
}

yukle();
