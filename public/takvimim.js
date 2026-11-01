const $ = id => document.getElementById(id);
const GUN = ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'];
const AY = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const TUR = {
  ders: { ad: 'Ders' },
  nobet: { ad: 'Nöbet' },
  gorev: { ad: 'Görevlendirme' },
  etut: { ad: 'Etüt' },
  toplanti: { ad: 'Toplantı' },
  odev: { ad: 'Ödev' },
  sinav: { ad: 'Sınav' },
  kulup: { ad: 'Kulüp çalışması' },
  rapor: { ad: 'Gelişim raporu' },
  veli: { ad: 'Veli toplantısı' },
  gorusme: { ad: 'Veli görüşmesi' },
  dogum: { ad: 'Doğum günü' },
};
const DURUM = { tamam: 'İşlendi', iptal: 'İptal' };

let gorunum = 'ay';
let secili = '';   // seçili gün
let bugun = '';
const onbellek = {}; // ay -> veri

function el(tag, metin, sinif) {
  const e = document.createElement(tag);
  if (metin !== undefined) e.textContent = metin;
  if (sinif) e.className = sinif;
  return e;
}
const kaydir = (t, n) => {
  const d = new Date(t + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};
const kisaTarih = t => { const d = new Date(t + 'T00:00:00Z'); return `${d.getUTCDate()} ${AY[d.getUTCMonth()].slice(0, 3)}`; };
const uzunTarih = t => { const d = new Date(t + 'T00:00:00Z'); return `${d.getUTCDate()} ${AY[d.getUTCMonth()]} ${GUN[d.getUTCDay()]}`; };
const pazartesi = t => kaydir(t, -((new Date(t + 'T00:00:00Z').getUTCDay() + 6) % 7));

async function ayGetir(ay) {
  if (onbellek[ay]) return onbellek[ay];
  const r = await fetch('/api/takvim?ay=' + ay);
  if (r.status === 401) { location.href = '/'; return null; }
  if (!r.ok) { location.href = '/panel'; return null; }
  const v = await r.json();
  v.harita = new Map(v.gunler.map(g => [g.tarih, g]));
  bugun = v.bugun;
  onbellek[ay] = v;
  return v;
}

// Bir günün satırı: sol renk çizgisi, saat aralığı, başlık ve açıklama
function satir(o) {
  const k = o.baglanti ? el('a', undefined, 'tk-satir') : el('div', undefined, 'tk-satir');
  if (o.baglanti) k.href = o.baglanti;
  k.classList.add('tk-' + o.tur);
  if (o.renk) k.style.setProperty('--ders', o.renk);
  const zaman = el('div', undefined, 'tk-zaman');
  zaman.append(el('strong', o.bas || '—'));
  if (o.bit) zaman.append(el('span', o.bit));
  const orta = el('div', undefined, 'tk-orta');
  const ust = el('div', undefined, 'tk-ust');
  if (o.tur === 'ders' && o.kisa) ust.append(dersChip(o.kisa, o.renk));
  ust.append(el('strong', o.baslik));
  if (o.tur !== 'ders') ust.append(el('span', TUR[o.tur].ad, 'tk-etiket'));
  if (DURUM[o.durum]) ust.append(el('span', DURUM[o.durum], 'durum-etiket' + (o.durum === 'tamam' ? ' tamam' : '')));
  orta.append(ust);
  if (o.alt) orta.append(el('span', o.alt, 'alt'));
  k.append(zaman, orta);
  return k;
}

function gunIcerigi(g, baslikla) {
  const kap = el('section', undefined, 'tk-gun' + (g.tarih === bugun ? ' bugun' : ''));
  if (baslikla) {
    const b = el('h3', uzunTarih(g.tarih), 'tk-gun-baslik');
    if (g.tarih === bugun) b.append(el('span', 'Bugün', 'tk-bugun'));
    kap.append(b);
  }
  if (!g.ogeler.length) {
    kap.append(el('p', g.tatil ? `${g.tatil} · okul tatil` : !g.acik ? 'Ders günü değil.' : 'Bu gün için kayıt yok.', 'bos-not'));
  } else {
    if (g.tatil) kap.append(el('p', `${g.tatil} · okul tatil`, 'alt'));
    for (const o of g.ogeler) kap.append(satir(o));
  }
  return kap;
}

// Ay ızgarası: her gün için türlere göre renkli noktalar
function ayCiz(v) {
  const t = el('div', undefined, 'tk-izgara');
  for (const ad of ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']) t.append(el('span', ad, 'tk-baslik'));
  const ay = v.ay;
  for (const g of v.gunler) {
    const b = el('button', undefined, 'tk-hucre');
    b.type = 'button';
    if (g.tarih.slice(0, 7) !== ay) b.classList.add('disari');
    if (!g.acik) b.classList.add('kapali');
    if (g.tatil) b.classList.add('tatil');
    if (g.tarih === bugun) b.classList.add('bugun');
    if (g.tarih === secili) b.classList.add('secili');
    b.setAttribute('aria-pressed', String(g.tarih === secili));
    b.setAttribute('aria-label', uzunTarih(g.tarih));
    if (g.tatil) b.title = g.tatil;
    b.append(el('strong', String(Number(g.tarih.slice(8)))));
    const noktalar = el('span', undefined, 'tk-noktalar');
    for (const tur of Object.keys(TUR)) {
      const n = g.ogeler.filter(o => o.tur === tur).length;
      if (n) noktalar.append(el('i', undefined, 'tk-nokta tk-n-' + tur));
    }
    b.append(noktalar);
    b.addEventListener('click', () => { secili = g.tarih; ciz(); $('secili-gun').scrollIntoView({ behavior: 'smooth', block: 'nearest' }); });
    t.append(b);
  }
  $('ay').replaceChildren(t);
}

function haftaCiz(v) {
  const bas = pazartesi(secili);
  const kap = el('div', undefined, 'tk-hafta');
  for (let i = 0; i < 7; i++) {
    const g = v.harita.get(kaydir(bas, i));
    if (!g) continue;
    // Ders günü olmayan ve boş günler gösterilmez
    if (!g.ogeler.length && !g.tatil && !g.acik) continue;
    kap.append(gunIcerigi(g, true));
  }
  $('hafta').replaceChildren(kap);
}

// Açıklama: yalnız görünen ayda/haftada olan türler, günün ayrıntılarının hemen üstünde
function lejantCiz(v) {
  const k = $('lejant');
  k.replaceChildren();
  const var_ = new Set(v.gunler.flatMap(g => g.ogeler.map(o => o.tur)));
  for (const tur of Object.keys(TUR)) {
    if (!var_.has(tur)) continue;
    const oge = el('span', undefined, 'tk-lejant-oge');
    oge.append(el('i', undefined, 'tk-nokta tk-n-' + tur), TUR[tur].ad);
    k.append(oge);
  }
}

async function ciz() {
  if (!secili) secili = bugun || '';
  let ay = (secili || new Date().toISOString().slice(0, 10)).slice(0, 7);
  let v = await ayGetir(ay);
  if (!v) return;
  if (!secili) { secili = bugun; ay = bugun.slice(0, 7); v = await ayGetir(ay); }
  // Hafta görünümünde hafta iki aya yayılabilir: seçili gün hangi aydaysa o ayın verisi ızgarada tam haftalarla gelir
  $('ay').classList.toggle('gizli', gorunum !== 'ay');
  $('hafta').classList.toggle('gizli', gorunum !== 'hafta');
  $('secili-gun').classList.toggle('gizli', gorunum !== 'ay');
  $('bugun').classList.toggle('bugunde', gorunum === 'ay' ? ay === bugun.slice(0, 7) : pazartesi(secili) === pazartesi(bugun));
  lejantCiz(v);
  const lejant = $('lejant');
  if (gorunum === 'ay') $('secili-gun').before(lejant); else $('hafta').before(lejant);
  if (gorunum === 'ay') {
    $('baslik').textContent = `${AY[Number(ay.slice(5)) - 1]} ${ay.slice(0, 4)}`;
    ayCiz(v);
    const g = v.harita.get(secili);
    const kap = el('div');
    if (g) { kap.append(el('h3', uzunTarih(g.tarih), 'tk-gun-baslik'), gunIcerigi(g, false)); }
    $('secili-gun').replaceChildren(kap);
  } else {
    const bas = pazartesi(secili), son = kaydir(bas, 6);
    $('baslik').textContent = `${kisaTarih(bas)} – ${kisaTarih(son)}`;
    haftaCiz(v);
  }
}

$('gorunum').addEventListener('click', e => {
  const b = e.target.closest('button');
  if (!b) return;
  gorunum = b.dataset.gorunum;
  for (const x of $('gorunum').children) x.setAttribute('aria-pressed', String(x === b));
  $('bugun').textContent = 'Bugün';
  ciz();
});
const adim = n => {
  if (gorunum === 'hafta') secili = kaydir(secili, 7 * n);
  else {
    const [y, a] = secili.split('-').map(Number);
    const d = new Date(Date.UTC(y, a - 1 + n, 1));
    const gun = Number(secili.slice(8));
    const sonGun = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
    d.setUTCDate(Math.min(gun, sonGun));
    secili = d.toISOString().slice(0, 10);
  }
  ciz();
};
$('geri').addEventListener('click', () => adim(-1));
$('ileri').addEventListener('click', () => adim(1));
$('bugun').addEventListener('click', () => { secili = bugun; ciz(); });
$('bugun').textContent = 'Bugün';

ciz();
