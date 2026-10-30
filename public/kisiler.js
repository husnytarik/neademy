const GOREV_AD = { mudur: 'Müdür', mudur_yrd: 'Müdür yardımcısı' };
const $ = id => document.getElementById(id);
let subeler = [], kampusler = [], kisiler = [], roller = [], secenek = null;
let yeniAcik = false;

function mesaj(metin, tur = '') {
  $('mesaj').textContent = metin;
  $('mesaj').className = 'mesaj ' + tur;
}

function el(tag, metin, sinif) {
  const e = document.createElement(tag);
  if (metin !== undefined) e.textContent = metin;
  if (sinif) e.className = sinif;
  return e;
}

async function api(yol, govde) {
  const r = await fetch(yol, govde === undefined ? {} : {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(govde),
  });
  if (r.status === 401) { location.href = '/'; throw new Error('oturum'); }
  const v = await r.json().catch(() => ({}));
  return { ok: r.ok, veri: v };
}

function secenekler(sel, liste, deger, etiket, bos) {
  sel.replaceChildren();
  if (bos !== undefined) sel.appendChild(new Option(bos, ''));
  for (const x of liste) sel.appendChild(new Option(etiket(x), deger(x)));
}

const kampusAd = id => kampusler.find(k => k.id === id)?.ad || '';
const okulEtiket = s => kampusler.length > 1 ? `${s.ad} · ${kampusAd(s.kampusId)}` : s.ad;
const personelUyelik = m => m.rol === 'yonetim' || m.rol === 'ogretmen';

// ---- Kişi özeti ----
const calisiyor = u => u.uyelikler.some(m => personelUyelik(m) && m.durum === 'aktif');

function gorevler(u) {
  const liste = [];
  if (u.uyelikler.some(m => m.rol === 'yonetim' && m.gorev === 'kurum' && m.durum === 'aktif')) liste.push('Kurum yönetimi');
  for (const g of u.okulGorevleri) liste.push(GOREV_AD[g.gorev]);
  for (const id of u.roller) { const r = roller.find(x => x.id === id); if (r && r.kod !== 'zumre') liste.push(r.ad); }
  const ogretmenler = u.uyelikler.filter(m => m.rol === 'ogretmen' && m.durum === 'aktif');
  if (ogretmenler.length) {
    const branslar = [...new Set(ogretmenler.map(m => secenek.dersler.find(d => d.id === m.bransId)?.ad).filter(Boolean))];
    liste.push(branslar.length ? branslar.join(' / ') + ' öğretmeni' : 'Öğretmen');
    if (ogretmenler.some(m => m.baskan)) liste.push('Zümre başkanı');
  }
  return [...new Set(liste)];
}

function okullari(u) {
  return [...new Set(u.uyelikler.filter(m => personelUyelik(m) && m.durum === 'aktif').map(m => m.sube).filter(Boolean))];
}

function suzulmus() {
  const okul = Number($('f-okul').value) || 0;
  const gorev = $('f-gorev').value;
  const durum = $('f-durum').value;
  const q = $('ara').value.trim().toLocaleLowerCase('tr');
  return kisiler.filter(u => {
    const m = u.uyelikler.filter(x => personelUyelik(x) && (!okul || x.subeId === okul));
    if (!m.length) return false;
    const aktif = m.some(x => x.durum === 'aktif');
    if (durum === 'aktif' && !aktif) return false;
    if (durum === 'pasif' && aktif) return false;
    if (gorev === 'ogretmen' && !m.some(x => x.rol === 'ogretmen')) return false;
    if (gorev === 'yonetim' && !m.some(x => x.rol === 'yonetim')) return false;
    if (gorev === 'mudur' && !u.okulGorevleri.length) return false;
    return !q || u.ad.toLocaleLowerCase('tr').includes(q);
  });
}

function satir(u) {
  const a = el('a', undefined, 'ol-satir kz-satir');
  a.href = '/kisi?id=' + u.id;
  const orta = el('div', undefined, 'ol-orta');
  const alt = el('small');
  const g = gorevler(u);
  const parcalar = [g.join(', ') || 'Görev atanmamış', okullari(u).join(', ')];
  if (!calisiyor(u)) parcalar.push('Ayrıldı');
  alt.textContent = parcalar.filter(Boolean).join(' · ');
  if (calisiyor(u) && !g.length) alt.classList.add('kad-uyari');
  orta.append(el('strong', u.ad), alt);
  a.append(avatarYap(u.ad, u.foto, 'kucuk'), orta, el('span', undefined, 'kad-ok'));
  if (!calisiyor(u)) a.classList.add('pasif');
  return a;
}

function ciz() {
  const kutu = $('liste');
  kutu.replaceChildren();
  const liste = suzulmus();
  for (const u of liste) kutu.append(satir(u));
  if (!liste.length) kutu.append(el('p', 'Bu seçimde kayıtlı kişi yok.', 'bos-not'));
  $('sayi').textContent = `${liste.length} kişi`;
  $('yeni').querySelector('span').textContent = yeniAcik ? 'Vazgeç' : 'Yeni kişi';
  $('yeni').classList.toggle('acik', yeniAcik);
  for (const id of ['f-okul', 'f-gorev', 'f-durum']) $(id).classList.toggle('suzulu', $(id).selectedIndex > 0);
  $('yeni-alan').classList.toggle('gizli', !yeniAcik);
  const o = $('f-okul');
  const kapsam = o.value ? o.options[o.selectedIndex].text : '';
  $('yazdir-baslik').textContent = `Personel${kapsam ? ' — ' + kapsam : ''} · ${new Date().toLocaleDateString('tr-TR')}`;
}

// ---- Yeni kişi ----
function girdiAlan(etiket, girdi) {
  const k = document.createElement('div');
  const l = el('label', etiket);
  l.append(girdi);
  k.append(l);
  return k;
}

function secimKutusu(metin, degisti) {
  const l = el('label', undefined, 'kz-secim');
  const c = Object.assign(document.createElement('input'), { type: 'checkbox' });
  c.addEventListener('change', degisti);
  l.append(c, el('span', metin));
  return { l, c };
}

function yeniKisiFormu() {
  const k = $('yeni-alan');
  k.replaceChildren(el('h4', 'Yeni kişi', 'kad-etiket'));
  const ad = Object.assign(document.createElement('input'), { required: true, maxLength: 80, autocomplete: 'off' });
  const kimlik = Object.assign(document.createElement('input'), { required: true, maxLength: 20, autocomplete: 'off' });
  const tel = Object.assign(document.createElement('input'), { type: 'tel', required: true, maxLength: 20, placeholder: '5XX XXX XX XX' });
  const okul = document.createElement('select');
  secenekler(okul, subeler, x => x.id, okulEtiket);
  const bilgi = el('p', '', 'alt kz-kontrol');

  const form = el('form');
  const girdiler = el('div', undefined, 'form-satir');
  girdiler.append(girdiAlan('Ad soyad', ad), girdiAlan('T.C. / pasaport no', kimlik), girdiAlan('Telefon', tel));
  if (subeler.length > 1) girdiler.append(girdiAlan('Okul', okul));
  form.append(girdiler);

  // Aynı kimlik zaten kayıtlıysa kişiyi tekrar açmak yerine dosyasına yönlendir
  kimlik.addEventListener('change', async () => {
    bilgi.replaceChildren();
    const v = kimlik.value.trim();
    if (v.length < 5) return;
    const r = await api('/api/yonetim/kullanici-kontrol?kimlik=' + encodeURIComponent(v));
    if (!r.ok || !r.veri.var) return;
    const a = el('a', r.veri.ad, 'kur-baglanti');
    a.href = '/kisi?id=' + r.veri.id;
    bilgi.append('Bu kimlik zaten kayıtlı: ', a, '. Yeni görev vermek için kişinin dosyasını açın; yine de eklerseniz aynı telefonu yazmanız gerekir.');
  });

  const gorevKutu = el('div', undefined, 'kz-gorev');
  const ogr = secimKutusu('Öğretmen', () => { dersKutu.classList.toggle('gizli', !ogr.c.checked); });
  const yon = secimKutusu('Yönetim', () => { yonKutu.classList.toggle('gizli', !yon.c.checked); });
  gorevKutu.append(el('h4', 'Görevi', 'kad-etiket'));

  const dersKutu = el('div', undefined, 'kz-alt gizli');
  dersKutu.append(el('h4', 'Verdiği dersler', 'kad-etiket'));
  const dersSecili = new Set();
  const dersler = el('div', undefined, 'kad-ciplar');
  for (const d of secenek.dersler) {
    const c = el('button', d.ad, 'kad-cip');
    c.type = 'button';
    c.setAttribute('aria-pressed', 'false');
    c.addEventListener('click', () => {
      if (dersSecili.has(d.id)) dersSecili.delete(d.id); else dersSecili.add(d.id);
      c.setAttribute('aria-pressed', String(dersSecili.has(d.id)));
    });
    dersler.append(c);
  }
  dersKutu.append(dersler);

  const yonKutu = el('div', undefined, 'kz-alt gizli');
  const rol = document.createElement('select');
  secenekler(rol, secenek.roller, r => r.id, r => r.ad, 'Rol (isteğe bağlı)');
  const mudur = document.createElement('select');
  secenekler(mudur, Object.entries(secenek.gorevler), g => g[0], g => g[1], 'Müdürlük görevi yok');
  const yonSatir = el('div', undefined, 'form-satir');
  yonSatir.append(girdiAlan('Rol', rol), girdiAlan('Müdürlük', mudur));
  yonKutu.append(yonSatir);

  gorevKutu.append(ogr.l, dersKutu, yon.l, yonKutu);
  form.append(bilgi, gorevKutu);
  const dugme = el('div');
  const gonder = el('button', 'Kişiyi ekle', 'birincil');
  gonder.type = 'submit';
  dugme.append(gonder);
  form.append(dugme);
  form.addEventListener('submit', async e => {
    e.preventDefault();
    if (!ogr.c.checked && !yon.c.checked) return mesaj('En az bir görev seçin: öğretmen ya da yönetim', 'hata');
    gonder.disabled = true;
    const r = await api('/api/yonetim/kullanici-yeni', {
      ad: ad.value, kimlik: kimlik.value, telefon: tel.value, subeId: Number(okul.value) || subeler[0]?.id,
      ogretmen: ogr.c.checked, dersIds: [...dersSecili],
      yonetim: yon.c.checked, rolId: rol.value ? Number(rol.value) : null, mudurGorev: mudur.value,
    });
    gonder.disabled = false;
    if (!r.ok) return mesaj(r.veri.hata || 'Hata', 'hata');
    location.href = '/kisi?id=' + r.veri.id + (r.veri.mevcut ? '&mevcut=1' : '&yeni=1');
  });
  k.append(form);
  ad.focus();
}

// ---- Yazdırma ----
function raporuHazirla() {
  const o = $('f-okul');
  const satirlar = suzulmus().map(u => ({ ad: u.ad, gorev: gorevler(u).join(', '), okullar: okullari(u).join(', '), tel: u.telefon }))
    .sort((a, b) => a.ad.localeCompare(b.ad, 'tr'));
  const kok = $('rapor');
  kok.replaceChildren();
  const kapsam = o.value ? o.options[o.selectedIndex].text : 'Tüm okullar';
  kok.append(el('h2', 'Personel listesi'), el('p', `${kapsam} · ${new Date().toLocaleDateString('tr-TR')}`, 'pr-alt'));
  const tablo = el('table'), ust = el('tr');
  for (const b of ['No', 'Ad soyad', 'Görev', 'Okul']) ust.append(el('th', b));
  tablo.append(el('thead'));
  tablo.firstChild.append(ust);
  const gv = el('tbody');
  satirlar.forEach((r, i) => { const t = el('tr'); for (const d of [String(i + 1), r.ad, r.gorev, r.okullar]) t.append(el('td', d)); gv.append(t); });
  tablo.append(gv);
  kok.append(tablo, el('p', `Toplam ${satirlar.length} kişi`, 'pr-alt'));
}

$('yazdir').addEventListener('click', () => {
  raporuHazirla();
  document.body.classList.add('rapor-yazdir');
  window.print();
});
window.addEventListener('afterprint', () => document.body.classList.remove('rapor-yazdir'));

for (const id of ['f-okul', 'f-gorev', 'f-durum']) $(id).addEventListener('change', ciz);
$('ara').addEventListener('input', ciz);

$('yeni').addEventListener('click', () => {
  yeniAcik = !yeniAcik;
  mesaj('');
  if (yeniAcik) yeniKisiFormu();
  ciz();
});

$('sekmeler').addEventListener('click', e => {
  const b = e.target.closest('button[data-git]');
  if (b) location.href = b.dataset.git;
});

(async () => {
  const [s, k, r, sec] = await Promise.all([
    api('/api/yonetim/subeler'), api('/api/yonetim/kullanicilar?tur=personel'),
    api('/api/yonetim/roller'), api('/api/yonetim/kullanici-secenek'),
  ]);
  if (!s.ok || !k.ok || !r.ok || !sec.ok) { location.href = '/panel'; return; }
  subeler = s.veri.subeler;
  kampusler = s.veri.kampusler;
  kisiler = k.veri.kullanicilar;
  roller = r.veri.roller;
  secenek = sec.veri;
  secenekler($('f-okul'), subeler, x => x.id, okulEtiket, 'Tüm okullar');
  ciz();
})();
