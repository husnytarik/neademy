const $ = id => document.getElementById(id);

let zumreler = [];
let secili = null;     // courseId
let veri = null;       // /api/zumre/detay yanıtı
let sekme = 'toplanti';
let duzenle;           // düzenlenen toplantı (null: yeni toplantı, undefined: form kapalı)
let kararForm = null;  // açık karar formu: { toplantiId, tarih, baslik, karar }
let baskanMi = false;  // herhangi bir zümrenin başkanı mı (Başkanlar sekmesi için)
let bToplantilar = null; // /api/zumre/baskanlar/liste yanıtı
let bKarar = null;     // karar yazılan başkanlar toplantısı id

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
const gunAdi = t => GUN[new Date(t + 'T00:00:00Z').getUTCDay()];
const uzunTarih = t => { const [, a, g] = t.split('-'); return `${Number(g)} ${AY[Number(a) - 1]} ${gunAdi(t)}`; };
const bugun = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
const kalan = t => Math.round((Date.parse(t) - Date.parse(bugun())) / 86400000);
const kalanYazi = n => n === 0 ? 'Bugün' : n === 1 ? 'Yarın' : `${n} gün sonra`;
const zamanYaz = ms => new Date(ms).toLocaleString('tr-TR', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' });

// ---- Toplantılar ----
function toplantiFormu() {
  const t = duzenle || { baslik: 'Zümre toplantısı', tekrar: 'haftalik', baslangic: '', saat: '15:00', yer: '', gundem: '' };
  const f = el('form', undefined, 'zm-form');
  let sayac = 0;
  const alan = (etiket, girdi) => {
    const d = el('div');
    girdi.id = 'zf' + sayac++;
    const l = el('label', etiket);
    l.htmlFor = girdi.id;
    d.append(l, girdi);
    return d;
  };
  const baslik = el('input'); baslik.maxLength = 80; baslik.value = t.baslik;
  const tarih = el('input'); tarih.type = 'date'; tarih.required = true; tarih.value = t.baslangic;
  const saat = el('input'); saat.type = 'time'; saat.required = true; saat.value = t.saat;
  const tekrar = el('select');
  for (const [k, ad] of Object.entries(veri.tekrarlar)) { const o = el('option', ad); o.value = k; tekrar.append(o); }
  tekrar.value = t.tekrar;
  const yer = el('input'); yer.maxLength = 60; yer.value = t.yer; yer.placeholder = 'Örn. Öğretmenler odası';
  const gundem = el('textarea'); gundem.maxLength = 500; gundem.value = t.gundem; gundem.placeholder = 'Gündem maddeleri (isteğe bağlı)';
  const s1 = el('div', undefined, 'form-satir'); s1.append(alan('Başlık', baslik), alan('Yer', yer));
  const s2 = el('div', undefined, 'form-satir'); s2.append(alan(duzenle ? 'Başlangıç tarihi' : 'İlk toplantı', tarih), alan('Saat', saat), alan('Tekrar', tekrar));
  const dugmeler = el('div', undefined, 'zm-dugme');
  const kaydet = el('button', duzenle ? 'Kaydet' : 'Toplantıyı ekle', 'birincil kucuk'); kaydet.type = 'submit';
  dugmeler.append(kaydet, dugme('Vazgeç', () => { duzenle = undefined; ciz(); }));
  f.append(s1, s2, alan('Gündem', gundem), dugmeler);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    const r = await api('/api/zumre/toplanti', { id: duzenle?.id, courseId: secili, baslik: baslik.value, tekrar: tekrar.value, tarih: tarih.value, saat: saat.value, yer: yer.value, gundem: gundem.value });
    if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj('Toplantı kaydedildi.', 'basari');
    duzenle = undefined;
    yukle();
  });
  return f;
}

function toplantiSatiri(t) {
  const s = el('div', undefined, 'zm-toplanti');
  const ilk = t.siradaki[0];
  const rozet = el('div', undefined, 'tarih-rozet');
  if (ilk) { const [, a, g] = ilk.split('-'); rozet.append(el('strong', String(Number(g))), el('span', AY[Number(a) - 1])); }
  else rozet.append(el('strong', '–'), el('span', 'bitti'));
  const orta = el('div', undefined, 'etut-orta');
  orta.append(el('strong', t.baslik));
  orta.append(el('span', [ilk ? `${gunAdi(ilk)} ${t.saat}` : t.saat, t.yer, veri.tekrarlar[t.tekrar]].filter(Boolean).join(' · '), 'etut-saat'));
  if (ilk) orta.append(el('span', kalanYazi(kalan(ilk)), 'alt'));
  if (t.siradaki.length > 1) orta.append(el('span', 'Sonraki: ' + t.siradaki.slice(1).map(uzunTarih).join(' · '), 'alt'));
  if (t.gundem) orta.append(el('p', t.gundem, 'zm-gundem'));
  if (veri.baskan && t.bekleyen) {
    const b = el('div', undefined, 'zm-bekleyen');
    b.append(el('span', `${uzunTarih(t.bekleyen)} toplantısı yapıldı, kararı yazılmadı`, 'alt'),
      dugme('Toplantıyı bitir', () => { kararForm = { toplantiId: t.id, tarih: t.bekleyen, baslik: t.baslik, karar: '' }; ciz(); }, 'birincil kucuk'));
    orta.append(b);
  }
  if (veri.baskan) {
    const d = el('div', undefined, 'zm-dugme');
    d.append(dugme('Düzenle', () => { duzenle = t; ciz(); }), dugme('Sil', async () => {
      if (!confirm(`"${t.baslik}" toplantısı silinsin mi?`)) return;
      const r = await api('/api/zumre/toplanti-sil', { courseId: secili, id: t.id });
      if (!r.ok) return mesaj(r.veri.hata || 'Silinemedi', 'hata');
      yukle();
    }, 'ikincil kucuk tehlike'));
    orta.append(d);
  }
  s.append(rozet, orta);
  return s;
}

function kararFormu() {
  const f = el('form', undefined, 'zm-form');
  const metin = el('textarea'); metin.maxLength = 2000; metin.required = true; metin.value = kararForm.karar;
  metin.placeholder = 'Toplantıda alınan kararlar, görevler, sonraki adımlar…';
  metin.setAttribute('aria-label', 'Alınan kararlar');
  const d = el('div', undefined, 'zm-dugme');
  const g = el('button', 'Kaydet', 'birincil kucuk'); g.type = 'submit';
  d.append(g, dugme('Vazgeç', () => { kararForm = null; ciz(); }));
  f.append(el('strong', `${kararForm.baslik} · ${uzunTarih(kararForm.tarih)}`), metin, d);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    const r = await api('/api/zumre/karar', { courseId: secili, toplantiId: kararForm.toplantiId, tarih: kararForm.tarih, karar: metin.value });
    if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj('Karar kaydedildi.', 'basari');
    kararForm = null;
    yukle();
  });
  return f;
}

function kararlariCiz(k) {
  if (!kararForm && !veri.kararlar.length) return;
  k.append(el('h2', 'Alınan kararlar', 'baslik3'));
  if (kararForm) k.append(kararFormu());
  for (const c of veri.kararlar) {
    const s = el('div', undefined, 'zm-yazi');
    const ust = el('div', undefined, 'zm-yazi-ust');
    ust.append(el('strong', `${c.baslik} · ${uzunTarih(c.tarih)} ${c.saat}`), el('small', c.yazan));
    s.append(ust, el('p', c.karar, 'zm-gundem'));
    if (veri.baskan) {
      const d = el('div', undefined, 'zm-dugme');
      d.append(dugme('Düzenle', () => { kararForm = { toplantiId: c.toplantiId, tarih: c.tarih, baslik: c.baslik, karar: c.karar }; ciz(); }),
        dugme('Sil', async () => {
          if (!confirm('Bu toplantı kararı silinsin mi?')) return;
          const r = await api('/api/zumre/karar-sil', { courseId: secili, id: c.id });
          if (!r.ok) return mesaj(r.veri.hata || 'Silinemedi', 'hata');
          yukle();
        }, 'ikincil kucuk tehlike'));
      s.append(d);
    }
    k.append(s);
  }
}

function toplantilariCiz(k) {
  if (veri.baskan && duzenle !== undefined) k.append(el('h2', duzenle ? 'Toplantıyı düzenle' : 'Yeni toplantı', 'baslik3'), toplantiFormu());
  else if (veri.baskan) { const sat = el('div', undefined, 'zm-ekle-satir'); sat.append(dugme('+ Toplantı ekle', () => { duzenle = null; ciz(); }, 'birincil')); k.append(sat); }
  if (!veri.toplantilar.length) {
    k.append(el('p', veri.baskan
      ? 'Henüz toplantı yok. Rutin toplantıyı ekleyin; zümre öğretmenlerinin paneline hatırlatma düşer.'
      : 'Zümre başkanı toplantı eklediğinde burada görünür ve panelinize hatırlatma düşer.', 'alt'));
    return kararlariCiz(k);
  }
  k.append(el('h2', 'Sıradaki toplantılar', 'baslik3'));
  for (const t of veri.toplantilar) k.append(toplantiSatiri(t));
  kararlariCiz(k);
}

// ---- Yazılar: zümredeki herkes yazabilir ----
function yaziFormu() {
  const f = el('form', undefined, 'zm-form');
  const yazi = el('textarea'); yazi.maxLength = 1000; yazi.required = true; yazi.placeholder = 'Zümreye bir not, duyuru ya da bilgi yazın…';
  yazi.setAttribute('aria-label', 'Zümreye yaz');
  const g = el('button', 'Paylaş', 'birincil kucuk'); g.type = 'submit';
  f.append(yazi, g);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    const r = await api('/api/zumre/yazi', { courseId: secili, metin: yazi.value });
    if (!r.ok) return mesaj(r.veri.hata || 'Paylaşılamadı', 'hata');
    mesaj('');
    yukle();
  });
  return f;
}

function yazilariCiz(k) {
  k.append(yaziFormu());
  if (!veri.yazilar.length) return k.append(el('p', 'Henüz yazı yok. Zümredeki herkes yazabilir.', 'alt'));
  for (const y of veri.yazilar) {
    const s = el('div', undefined, 'zm-yazi');
    const ust = el('div', undefined, 'zm-yazi-ust');
    ust.append(el('strong', y.yazan));
    if (y.baskan) ust.append(el('span', 'Zümre başkanı', 'zm-etiket'));
    ust.append(el('small', zamanYaz(y.zaman)));
    s.append(ust, el('p', y.metin, 'zm-gundem'));
    if (y.benim || veri.baskan) {
      s.append(dugme('Sil', async () => {
        if (!confirm('Bu yazı silinsin mi?')) return;
        const r = await api('/api/zumre/yazi-sil', { courseId: secili, id: y.id });
        if (!r.ok) return mesaj(r.veri.hata || 'Silinemedi', 'hata');
        yukle();
      }, 'ikincil kucuk tehlike'));
    }
    k.append(s);
  }
}

// ---- Başkanlar: yönetimin kurduğu zümre başkanları toplantıları ----
function baskanlarCiz(k) {
  if (!bToplantilar) return k.append(el('p', 'Yükleniyor…', 'alt'));
  if (!bToplantilar.toplantilar.length) return k.append(el('p', 'Yönetim zümre başkanları toplantısı kurduğunda burada görünür; toplantıdan sonra alınan kararlar da burada yazılır.', 'alt'));
  k.append(el('p', 'Bu toplantılar ve kararları yalnızca yönetim ile zümre başkanlarına görünür.', 'alt'));
  for (const t of bToplantilar.toplantilar) {
    const s = el('div', undefined, 'zm-yazi');
    const ust = el('div', undefined, 'zm-yazi-ust');
    ust.append(el('strong', t.baslik), el('small', `${uzunTarih(t.tarih)} ${t.saat}${t.yer ? ' · ' + t.yer : ''}`));
    s.append(ust);
    if (t.gundem) s.append(el('p', t.gundem, 'zm-gundem'));
    if (bKarar === t.id) {
      const f = el('form', undefined, 'zm-form');
      const m = el('textarea'); m.maxLength = 2000; m.value = t.karar; m.placeholder = 'Toplantıda alınan kararlar…';
      m.setAttribute('aria-label', 'Alınan kararlar');
      const d = el('div', undefined, 'zm-dugme');
      const g = el('button', 'Kaydet', 'birincil kucuk'); g.type = 'submit';
      d.append(g, dugme('Vazgeç', () => { bKarar = null; ciz(); }));
      f.append(m, d);
      f.addEventListener('submit', async e => {
        e.preventDefault();
        const r = await api('/api/zumre/baskanlar/karar', { id: t.id, karar: m.value });
        if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
        mesaj('Karar kaydedildi.', 'basari');
        bKarar = null;
        baskanlariYukle();
      });
      s.append(f);
    } else {
      if (t.karar) {
        s.append(el('strong', 'Alınan kararlar'), el('p', t.karar, 'zm-gundem'));
        s.append(el('small', `${t.kararYazan || ''} · ${zamanYaz(t.kararZamani)}`));
      } else if (t.basladi) s.append(el('p', 'Karar henüz yazılmadı.', 'alt'));
      if (t.basladi) {
        const d = el('div', undefined, 'zm-dugme');
        d.append(dugme(t.karar ? 'Kararı düzenle' : 'Toplantıyı bitir', () => { bKarar = t.id; ciz(); }, t.karar ? 'ikincil kucuk' : 'birincil kucuk'));
        s.append(d);
      }
    }
    k.append(s);
  }
}

async function baskanlariYukle() {
  const r = await api('/api/zumre/baskanlar/liste');
  if (!r.ok) return mesaj(r.veri.hata || 'Toplantılar yüklenemedi', 'hata');
  bToplantilar = r.veri;
  ciz();
}

// ---- Öğretmenler ----
function ogretmenleriCiz(k) {
  k.append(el('p', `${veri.zumre.ad} zümresinde ${veri.ogretmenler.length} öğretmen var.`, 'alt'));
  for (const o of veri.ogretmenler) {
    const s = el('div', undefined, 'ogd-satir');
    const sol = el('div');
    sol.append(el('strong', o.ad + (o.ben ? ' (siz)' : '')), el('small', o.baskan ? 'Zümre başkanı' : 'Öğretmen'));
    s.append(sol);
    if (o.telefon && !o.ben) { const a = el('a', o.telefon, 'ogd-sayi'); a.href = 'tel:' + o.telefon; s.append(a); }
    k.append(s);
  }
}

const CIZIMLER = { toplanti: toplantilariCiz, yazi: yazilariCiz, ogretmen: ogretmenleriCiz, baskanlar: baskanlarCiz };

function ciz() {
  for (const b of $('z-sekmeler').children) b.setAttribute('aria-pressed', String(b.dataset.sekme === sekme));
  $('z-sekmeler').querySelector('[data-sekme="baskanlar"]').classList.toggle('gizli', !baskanMi);
  for (const [ad, f] of Object.entries(CIZIMLER)) {
    const k = $(ad);
    k.classList.toggle('gizli', ad !== sekme);
    k.replaceChildren();
    if (ad === sekme && veri) f(k);
  }
}

function zumreSecimi() {
  const k = $('zumre-sec');
  k.replaceChildren();
  k.classList.toggle('gizli', zumreler.length < 2);
  for (const z of zumreler) {
    const b = el('button', z.ad);
    b.type = 'button';
    b.setAttribute('aria-pressed', String(z.id === secili));
    b.addEventListener('click', () => { secili = z.id; duzenle = undefined; kararForm = null; zumreSecimi(); yukle(); });
    k.append(b);
  }
}

async function yukle() {
  const r = await api('/api/zumre/detay?courseId=' + secili);
  if (!r.ok) return mesaj(r.veri.hata || 'Zümre yüklenemedi', 'hata');
  veri = r.veri;
  $('baslik').textContent = `${veri.zumre.ad} zümresi`;
  ciz();
}

for (const b of $('z-sekmeler').children) b.addEventListener('click', () => { sekme = b.dataset.sekme; mesaj(''); ciz(); if (sekme === 'baskanlar') baskanlariYukle(); });

(async () => {
  const r = await api('/api/zumre/benim');
  if (!r.ok) return mesaj(r.veri.hata || 'Zümre bilgisi alınamadı', 'hata');
  zumreler = r.veri.zumreler;
  baskanMi = !!r.veri.baskan;
  if (!zumreler.length) return mesaj('Bir derse atanmadığınız için zümreniz yok.');
  if (baskanMi && new URLSearchParams(location.search).get('sekme') === 'baskanlar') { sekme = 'baskanlar'; baskanlariYukle(); }
  const istenen = Number(new URLSearchParams(location.search).get('courseId'));
  secili = (zumreler.find(z => z.id === istenen) || zumreler[0]).id;
  zumreSecimi();
  yukle();
})();
