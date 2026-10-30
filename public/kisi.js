const DIGER_AD = { ogrenci: 'Öğrenci', veli: 'Veli' };
const $ = id => document.getElementById(id);
const id = Number(new URLSearchParams(location.search).get('id'));
let secenek = null, k = null, zumreRolu = null;
let kimlikDuzen = false, dersDuzen = false;
const dersSecili = new Map(); // uyelikId -> Set(dersId), düzenleme sırasında
const bransSecili = new Map(), baskanSecili = new Map(); // uyelikId -> branş dersId / zümre başkanı mı

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

function kadLink(metin, tikla, sinif = '') {
  const b = el('button', metin, 'kad-link ' + sinif);
  b.type = 'button';
  b.addEventListener('click', tikla);
  return b;
}

function girdiAlan(etiket, girdi) {
  const d = document.createElement('div');
  const l = el('label', etiket);
  l.append(girdi);
  d.append(l);
  return d;
}

// İşlem sonrası: hatayı ya da başarıyı bildir, dosyayı yenile
async function sonuc(yanit, basari) {
  if (!yanit.ok) { mesaj(yanit.veri.hata || 'Hata', 'hata'); return false; }
  mesaj(basari || '', basari ? 'tamam' : '');
  await yukle();
  return true;
}

const calisiyor = () => k.uyelikler.some(m => m.durum === 'aktif');
const ogretmenUyelikleri = () => k.uyelikler.filter(m => m.rol === 'ogretmen');
const dersAd = d => secenek.dersler.find(x => x.id === d)?.ad || '';

function bolum(baslik, ...cocuklar) {
  const b = el('section', undefined, 'kad-bolum kz-bolum');
  b.append(el('h4', baslik, 'kad-etiket'), ...cocuklar);
  return b;
}

function satirYaz(etiket, deger) {
  const s = el('div', undefined, 'kz-bilgi');
  s.append(el('span', etiket), el('b', deger || '—'));
  return s;
}

// Başlıktaki unvan: kurum yönetimi, müdürlük, yönetici, öğretmen (branşıyla), zümre başkanı
function unvanlar() {
  const aktif = k.uyelikler.filter(m => m.durum === 'aktif');
  const cokOkul = secenek.okullar.length > 1;
  const liste = [];
  if (aktif.some(m => m.rol === 'yonetim' && m.gorev === 'kurum')) liste.push('Kurum yönetimi');
  for (const g of k.okulGorevleri) liste.push(secenek.gorevler[g.gorev] + (cokOkul ? ' · ' + g.okul : ''));
  if (!liste.length && aktif.some(m => m.rol === 'yonetim')) liste.push('Yönetici');
  const ogretmenIds = new Set(aktif.filter(m => m.rol === 'ogretmen').map(m => m.id));
  if (ogretmenIds.size) {
    const branslar = [...new Set(aktif.filter(m => ogretmenIds.has(m.id) && m.bransId).map(m => dersAd(m.bransId)).filter(Boolean))];
    liste.push(branslar.length ? branslar.join(' / ') + ' öğretmeni' : 'Öğretmen');
    if (aktif.some(m => m.rol === 'ogretmen' && m.baskan)) liste.push('Zümre başkanı');
  }
  for (const m of k.diger.filter(m => m.durum === 'aktif')) liste.push(DIGER_AD[m.rol]);
  return liste;
}

// ---- Başlık: foto, ad, durum ----
function baslik() {
  const kap = el('div', undefined, 'kz-baslik');
  const girdi = Object.assign(document.createElement('input'), { type: 'file', accept: 'image/*', hidden: true });
  const sec = kadLink(k.foto ? 'Fotoğrafı değiştir' : 'Fotoğraf ekle', () => girdi.click());
  girdi.addEventListener('change', async () => {
    const d = girdi.files[0];
    girdi.value = '';
    if (!d) return;
    sec.disabled = true;
    let govde;
    try { govde = (await fotoKirp(d, { baslik: k.ad }))?.blob; } catch { sec.disabled = false; return mesaj('Bu fotoğraf okunamadı, başka bir fotoğraf deneyin', 'hata'); }
    if (!govde) { sec.disabled = false; return; }
    const r = await fetch('/api/foto?id=' + k.id, { method: 'POST', headers: { 'Content-Type': 'image/jpeg' }, body: govde });
    if (r.status === 401) { location.href = '/'; return; }
    if (!r.ok) { sec.disabled = false; return mesaj((await r.json().catch(() => ({}))).hata || 'Fotoğraf yüklenemedi', 'hata'); }
    mesaj('Fotoğraf güncellendi.', 'tamam');
    yukle();
  });
  const linkler = el('div', undefined, 'kad-linkler');
  linkler.append(sec, girdi);
  if (k.foto) linkler.append(kadLink('Kaldır', async () => sonuc(await api('/api/foto-sil?id=' + k.id, {}), 'Fotoğraf kaldırıldı.')));
  const metin = el('div', undefined, 'kz-ad');
  metin.append(el('h2', k.ad));
  const unvan = unvanlar();
  if (unvan.length) metin.append(el('p', unvan.join(' · '), 'kz-unvan'));
  const etiketler = el('div', undefined, 'kad-ciplar');
  for (const r of secenek.roller.filter(r => k.roller.includes(r.id))) etiketler.append(el('span', r.ad, 'kz-durum'));
  if (!calisiyor()) etiketler.append(el('span', 'Okuldan ayrıldı', 'kz-durum pasif'));
  if (etiketler.children.length) metin.append(etiketler);
  metin.append(linkler);
  kap.append(avatarYap(k.ad, k.foto, 'buyuk'), metin);
  return kap;
}

// ---- Kimlik ----
function kimlikBolumu() {
  if (!kimlikDuzen) {
    const b = bolum('Kimlik ve iletişim',
      satirYaz('Ad soyad', k.ad), satirYaz(k.kimlikTuru === 'Pasaport' ? 'Pasaport no' : 'T.C. kimlik no', k.kimlik), satirYaz('Giriş telefonu', k.telefon));
    b.append(kadLink('Düzenle', () => { kimlikDuzen = true; ciz(); }));
    return b;
  }
  const f = el('form', undefined, 'form-satir');
  const ad = Object.assign(document.createElement('input'), { value: k.ad, required: true, maxLength: 80 });
  const kimlik = Object.assign(document.createElement('input'), { maxLength: 20, placeholder: `${k.kimlik} (değişmeyecekse boş bırakın)`, autocomplete: 'off' });
  const tel = Object.assign(document.createElement('input'), { type: 'tel', maxLength: 20, placeholder: `${k.telefon} (değişmeyecekse boş bırakın)` });
  f.append(girdiAlan('Ad soyad', ad), girdiAlan(k.kimlikTuru === 'Pasaport' ? 'Pasaport no' : 'T.C. kimlik no', kimlik), girdiAlan('Giriş telefonu', tel));
  const alt = el('div', undefined, 'kad-alt-dugmeler');
  const kaydet = el('button', 'Kaydet', 'ekle-ac kad-dolu');
  kaydet.type = 'submit';
  alt.append(kaydet, kadLink('Vazgeç', () => { kimlikDuzen = false; ciz(); }));
  f.append(alt);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    kaydet.disabled = true;
    const r = await api('/api/yonetim/kullanici-kimlik', { userId: k.id, ad: ad.value, kimlik: kimlik.value, telefon: tel.value });
    kaydet.disabled = false;
    if (r.ok) kimlikDuzen = false;
    sonuc(r, 'Bilgiler güncellendi.');
  });
  return bolum('Kimlik ve iletişim', f);
}

// ---- Görevler: görünümde yalnızca verilenler görünür; Düzenle ile düğmeler açılır, Kaydet ile kaydolur ----
let gorevDuzen = false, taslak = null, veliAcik = false, ogrVeri = null;

const kurumdaMi = () => k.uyelikler.some(m => m.rol === 'yonetim' && m.gorev === 'kurum' && m.durum === 'aktif');

function okulDurum(okul) {
  const uye = rol => k.uyelikler.find(m => m.rol === rol && m.subeId === okul.id);
  const yon = uye('yonetim'), ogr = uye('ogretmen');
  return { yon, ogr, yonAcik: yon?.durum === 'aktif', ogrAcik: ogr?.durum === 'aktif', mudur: k.okulGorevleri.find(g => g.okulId === okul.id)?.gorev || '' };
}

// Düzenleme sırasındaki seçimler; Kaydet'e basılana dek sunucuya gitmez
function taslakKur() {
  taslak = { yon: new Map(), ogr: new Map(), mudur: new Map(), roller: new Set(k.roller), veliCikar: new Set(), veliEkle: [] };
  for (const okul of secenek.okullar) {
    const d = okulDurum(okul);
    taslak.yon.set(okul.id, d.yonAcik);
    taslak.ogr.set(okul.id, d.ogrAcik);
    taslak.mudur.set(okul.id, d.mudur);
  }
}

function gorevDugmesi(ad, acik, tikla, kilit = '') {
  const c = el('button', ad, 'kad-cip');
  c.type = 'button';
  c.setAttribute('aria-pressed', String(acik));
  if (kilit) { c.disabled = true; c.title = kilit; } else c.addEventListener('click', tikla);
  return c;
}

const sabitCip = ad => el('span', ad, 'kad-cip sabit');

async function ogrenciVerisi() {
  if (ogrVeri) return ogrVeri;
  const [l, s] = await Promise.all([api('/api/ogrenci/liste'), api('/api/ogrenci/kayit')]);
  ogrVeri = { liste: l.ok ? l.veri.ogrenciler.filter(o => o.durum === 'aktif') : [], yakinlik: s.ok ? s.veri.secenekler.yakinlik : [] };
  return ogrVeri;
}

const veliMetin = o => [o.ad, o.yakinlik, o.sinif || o.sube].filter(Boolean).join(' · ');
const kalanVeli = () => k.veliOgrenciler.filter(o => !taslak.veliCikar.has(o.id));

function veliPaneli() {
  const p = el('div', undefined, 'kz-veli');
  for (const o of k.veliOgrenciler) {
    const s = el('div', undefined, 'kad-uyelik');
    const cikacak = taslak.veliCikar.has(o.id);
    const a = el('a', veliMetin(o), 'kad-link' + (cikacak ? ' kaldirilacak' : ''));
    a.href = '/ogrenci-dosyasi?id=' + o.id;
    s.append(a, cikacak
      ? kadLink('Geri al', () => { taslak.veliCikar.delete(o.id); gorevYenile(); })
      : kadLink('Çıkar', () => { taslak.veliCikar.add(o.id); gorevYenile(); }, 'tehlike'));
    p.append(s);
  }
  for (const e of taslak.veliEkle) {
    const s = el('div', undefined, 'kad-uyelik');
    s.append(el('span', `${e.metin} · ${e.yakinlik} (eklenecek)`), kadLink('Vazgeç', () => { taslak.veliEkle = taslak.veliEkle.filter(x => x !== e); gorevYenile(); }));
    p.append(s);
  }
  const f = el('form', undefined, 'kad-ekle');
  const ara = Object.assign(document.createElement('input'), { type: 'search', placeholder: 'Öğrenci adı ya da okul no', maxLength: 60 });
  const sec = document.createElement('select'), yak = document.createElement('select');
  ara.setAttribute('aria-label', 'Öğrenci ara'); sec.setAttribute('aria-label', 'Öğrenci'); yak.setAttribute('aria-label', 'Yakınlık');
  const ekle = el('button', 'Ekle', 'ekle-ac kad-dolu');
  ekle.type = 'submit';
  const doldur = () => {
    if (!ogrVeri) return;
    const q = ara.value.trim().toLocaleLowerCase('tr');
    const var_ = new Set([...k.veliOgrenciler.map(o => o.id), ...taslak.veliEkle.map(e => e.id)]);
    const uygun = ogrVeri.liste.filter(o => !var_.has(o.id) && (!q || o.ad.toLocaleLowerCase('tr').includes(q) || String(o.okulNo || '').includes(q))).slice(0, 40);
    sec.replaceChildren(...uygun.map(o => new Option([o.ad, o.sinif || 'Sınıfsız', o.okulNo ? 'No ' + o.okulNo : ''].filter(Boolean).join(' · '), String(o.id))));
    if (!uygun.length) sec.append(new Option('Eşleşen öğrenci yok', ''));
  };
  ogrenciVerisi().then(v => { yak.replaceChildren(new Option('Yakınlık', ''), ...v.yakinlik.map(y => new Option(y, y))); doldur(); });
  ara.addEventListener('input', doldur);
  f.append(ara, sec, yak, ekle);
  f.addEventListener('submit', e => {
    e.preventDefault();
    if (!sec.value) return mesaj('Öğrenci seçin', 'hata');
    if (!yak.value) return mesaj('Yakınlık seçin', 'hata');
    mesaj('');
    taslak.veliEkle.push({ id: Number(sec.value), yakinlik: yak.value, metin: sec.selectedOptions[0].textContent.split(' · ')[0] });
    gorevYenile();
  });
  p.append(f);
  return p;
}

function gorevOku(b) {
  const cokOkul = secenek.okullar.length > 1;
  const kurumda = kurumdaMi();
  let var_ = false;
  if (kurumda) { var_ = true; b.append(el('p', 'Kurum yönetimi üyesi: tüm okullarda yönetim yetkisi vardır.', 'alt')); }
  for (const okul of secenek.okullar) {
    const d = okulDurum(okul);
    const adlar = [];
    if (d.yonAcik && !kurumda) adlar.push('Yönetim');
    if (d.mudur) adlar.push(secenek.gorevler[d.mudur]);
    if (d.ogrAcik) adlar.push('Öğretmen');
    if (!adlar.length) continue;
    var_ = true;
    const satir = el('div', undefined, 'kz-gorev-satir');
    if (cokOkul) satir.append(el('b', okul.ad, 'kz-okul'));
    const cipler = el('div', undefined, 'kad-ciplar');
    cipler.append(...adlar.map(sabitCip));
    satir.append(cipler);
    b.append(satir);
  }
  const ogr = k.diger.find(m => m.rol === 'ogrenci' && m.durum === 'aktif');
  if (ogr || k.veliOgrenciler.length) {
    var_ = true;
    const kap = el('div', undefined, 'kz-ogr-veli');
    kap.append(el('h4', 'Öğrenci ve veli', 'kad-etiket'));
    const cipler = el('div', undefined, 'kad-ciplar');
    if (ogr) cipler.append(sabitCip('Öğrenci'));
    if (k.veliOgrenciler.length) cipler.append(sabitCip('Veli'));
    kap.append(cipler);
    for (const o of k.veliOgrenciler) {
      const a = el('a', veliMetin(o), 'kad-link');
      a.href = '/ogrenci-dosyasi?id=' + o.id;
      kap.append(a);
    }
    b.append(kap);
  }
  if (k.roller.length) {
    var_ = true;
    b.append(el('h4', 'Ek görevler', 'kad-etiket'));
    const cipler = el('div', undefined, 'kad-ciplar');
    cipler.append(...secenek.roller.filter(r => k.roller.includes(r.id)).map(r => sabitCip(r.ad)));
    b.append(cipler);
  }
  if (!var_) b.append(el('p', 'Henüz görev verilmemiş.', 'alt'));
  b.append(kadLink('Düzenle', () => { gorevDuzen = true; veliAcik = false; taslakKur(); ogrenciVerisi(); ciz(); }));
}

function gorevDuzenle(b) {
  const cokOkul = secenek.okullar.length > 1;
  const kurumda = kurumdaMi();
  if (kurumda) b.append(el('p', 'Kurum yönetimi üyesi: tüm okullarda yönetim yetkisi vardır.', 'alt'));
  const aktifOkul = k.uyelikler.filter(m => m.durum === 'aktif' && m.subeId).map(m => m.subeId);

  for (const okul of secenek.okullar) {
    const d = okulDurum(okul);
    const mudur = taslak.mudur.get(okul.id);
    const satir = el('div', undefined, 'kz-gorev-satir');
    if (cokOkul) satir.append(el('b', okul.ad, 'kz-okul'));
    const cipler = el('div', undefined, 'kad-ciplar');

    // Kurum yönetimi her okulda zaten yetkilidir; ayrıca okul yönetimi seçilmez
    if (!kurumda) {
      const kilit = mudur ? 'Müdürlük görevi yönetim yetkisini içerir' : k.kendisi && d.yonAcik ? 'Kendi yönetim yetkinizi kaldıramazsınız' : '';
      cipler.append(gorevDugmesi('Yönetim', !!mudur || taslak.yon.get(okul.id), () => { taslak.yon.set(okul.id, !taslak.yon.get(okul.id)); gorevYenile(); }, kilit));
    }
    for (const [kod, ad] of Object.entries(secenek.gorevler)) {
      cipler.append(gorevDugmesi(ad, mudur === kod, () => { taslak.mudur.set(okul.id, mudur === kod ? '' : kod); gorevYenile(); }));
    }
    const ogrKilit = d.ogrAcik && (k.atamalar.some(a => a.uyelikId === d.ogr.id) || k.sinifOgretmenligi.length) ? 'Önce sınıf atamalarını ve sınıf öğretmenliğini başkasına verin' : '';
    cipler.append(gorevDugmesi('Öğretmen', taslak.ogr.get(okul.id), () => { taslak.ogr.set(okul.id, !taslak.ogr.get(okul.id)); gorevYenile(); }, ogrKilit));
    satir.append(cipler);
    b.append(satir);
  }

  // Öğrenci ve veli
  const kap = el('div', undefined, 'kz-ogr-veli');
  kap.append(el('h4', 'Öğrenci ve veli', 'kad-etiket'));
  const cipler = el('div', undefined, 'kad-ciplar');
  const ogr = k.diger.find(m => m.rol === 'ogrenci' && m.durum === 'aktif');
  cipler.append(gorevDugmesi('Öğrenci', !!ogr, () => {
    if (ogr) { location.href = '/ogrenci-dosyasi?id=' + ogr.id; return; }
    if (confirm('Öğrenci kaydı, öğrenci kayıt formundan açılır; aynı kimlik numarası girilirse bu kişinin mevcut hesabı kullanılır. Kaydedilmemiş değişiklikler kaybolur. Forma gidilsin mi?')) location.href = '/ogrenci-kayit';
  }));
  const veliVar = kalanVeli().length + taslak.veliEkle.length > 0;
  cipler.append(gorevDugmesi('Veli', veliVar || veliAcik, () => {
    // Açıkken dokunmak tüm veli bağlantılarını kaldırmaya işaretler (Kaydet'e dek geri alınabilir)
    if (veliVar) { kalanVeli().forEach(o => taslak.veliCikar.add(o.id)); taslak.veliEkle = []; veliAcik = false; } else veliAcik = !veliAcik;
    gorevYenile();
  }));
  kap.append(cipler);
  if (veliVar || veliAcik || taslak.veliCikar.size) kap.append(veliPaneli());
  b.append(kap);

  // Ek görevler (zümre başkanı, rehber öğretmen gibi)
  if (calisiyor() && aktifOkul.length) {
    b.append(el('h4', 'Ek görevler', 'kad-etiket'));
    const ek = el('div', undefined, 'kad-ciplar');
    for (const r of secenek.roller) {
      const c = gorevDugmesi(r.ad, taslak.roller.has(r.id), () => { if (taslak.roller.has(r.id)) taslak.roller.delete(r.id); else taslak.roller.add(r.id); gorevYenile(); });
      c.title = r.aciklama || '';
      ek.append(c);
    }
    b.append(ek);
  }

  const alt = el('div', undefined, 'kad-alt-dugmeler');
  const kaydet = el('button', 'Kaydet', 'ekle-ac kad-dolu');
  kaydet.type = 'button';
  kaydet.addEventListener('click', () => gorevKaydet(kaydet));
  alt.append(kaydet, kadLink('Vazgeç', () => { gorevDuzen = false; taslak = null; mesaj(''); ciz(); }));
  b.append(alt);
}

// Taslağı özgün durumla karşılaştırıp yalnızca değişenleri sırayla sunucuya gönderir
async function gorevKaydet(dugme) {
  const kurumda = kurumdaMi();
  const islemler = [];
  let onay = '';
  const kaynak = k.uyelikler.find(m => m.rol === 'yonetim' && m.durum === 'aktif') || k.uyelikler.find(m => m.durum === 'aktif');
  for (const r of secenek.roller) {
    const ver = taslak.roller.has(r.id);
    if (ver !== k.roller.includes(r.id)) islemler.push(['/api/yonetim/kullanici-rol', { userId: k.id, rolId: r.id, ver, subeId: kaynak?.subeId }]);
  }
  for (const okul of secenek.okullar) {
    const d = okulDurum(okul);
    const mudur = taslak.mudur.get(okul.id);
    if (mudur !== d.mudur) islemler.push(['/api/yonetim/kullanici-mudur', { userId: k.id, okulId: okul.id, gorev: mudur }]);
    if (!kurumda && !mudur) {
      const yon = taslak.yon.get(okul.id);
      // Müdürlük kalkınca sunucu yönetim üyeliğini de kapatır; yönetim seçili kaldıysa yeniden açılır
      if (yon !== d.yonAcik || (d.mudur && yon)) {
        islemler.push(yon
          ? (d.yon ? ['/api/yonetim/uyelik-durum', { uyelikId: d.yon.id, durum: 'aktif' }] : ['/api/yonetim/uyelik-ekle', { userId: k.id, subeId: okul.id, rol: 'yonetim' }])
          : ['/api/yonetim/uyelik-durum', { uyelikId: d.yon.id, durum: 'pasif' }]);
        if (!yon && k.roller.length) onay = 'Yönetim kaldırılırsa kişinin ek görevleri de çalışmaz. ';
      }
    }
    const ogr = taslak.ogr.get(okul.id);
    if (ogr !== d.ogrAcik) islemler.push(ogr
      ? (d.ogr ? ['/api/yonetim/uyelik-durum', { uyelikId: d.ogr.id, durum: 'aktif' }] : ['/api/yonetim/uyelik-ekle', { userId: k.id, subeId: okul.id, rol: 'ogretmen' }])
      : ['/api/yonetim/uyelik-durum', { uyelikId: d.ogr.id, durum: 'pasif' }]);
  }
  for (const id of taslak.veliCikar) islemler.push(['/api/yonetim/kullanici-veli', { userId: k.id, ogrenciId: id, ver: false }]);
  for (const e of taslak.veliEkle) islemler.push(['/api/yonetim/kullanici-veli', { userId: k.id, ogrenciId: e.id, yakinlik: e.yakinlik }]);

  if (!islemler.length) { gorevDuzen = false; taslak = null; mesaj(''); return ciz(); }
  if (taslak.veliCikar.size) onay += `${taslak.veliCikar.size} öğrencinin veli bağlantısı kaldırılacak. `;
  if (onay && !confirm(onay + 'Devam edilsin mi?')) return;
  dugme.disabled = true;
  for (const [yol, govde] of islemler) {
    const r = await api(yol, govde);
    if (!r.ok) {
      const hata = (r.veri.hata || 'Hata') + (islemler.length > 1 ? ' (öncesindeki değişiklikler kaydedildi)' : '');
      await yukle();
      return mesaj(hata, 'hata');
    }
  }
  gorevDuzen = false;
  taslak = null;
  await yukle();
  mesaj('Görevler güncellendi.', 'tamam');
}

function gorevBolumu() {
  const b = bolum('Görevler');
  b.id = 'gorevler';
  if (gorevDuzen) gorevDuzenle(b); else gorevOku(b);
  return b;
}

function gorevYenile() {
  $('gorevler').replaceWith(gorevBolumu());
}

// ---- Branş, verdiği dersler ve atamalar ----
function dersBolumu() {
  const uyeler = ogretmenUyelikleri();
  if (!uyeler.length) return null;
  const b = bolum('Branş ve dersler');
  for (const m of uyeler) {
    const secili = dersSecili.get(m.id) ?? new Set(k.dersler.filter(d => d.uyelikId === m.id).map(d => d.dersId));
    const brans = bransSecili.has(m.id) ? bransSecili.get(m.id) : m.bransId;
    const baskan = baskanSecili.has(m.id) ? baskanSecili.get(m.id) : m.baskan;
    const kutu = el('div', undefined, 'kz-ders');
    if (uyeler.length > 1) kutu.append(el('b', m.sube, 'kz-okul'));
    if (!dersDuzen) {
      kutu.append(satirYaz('Branş', brans ? dersAd(brans) + (baskan ? ' · Zümre başkanı' : '') : 'Branş seçilmemiş'));
      const cipler = el('div', undefined, 'kad-ciplar');
      for (const d of secili) if (d !== brans) cipler.append(el('span', dersAd(d), 'kad-cip sabit'));
      if (cipler.children.length) kutu.append(el('h4', 'Verdiği diğer dersler', 'kad-etiket'), cipler);
    } else {
      kutu.append(el('label', 'Branş', 'kad-etiket'));
      const sec = el('select');
      sec.append(new Option('Branş seçin', ''));
      for (const d of secenek.dersler) sec.append(new Option(d.ad, d.id));
      sec.value = brans ?? '';
      sec.addEventListener('change', () => {
        const yeni = sec.value ? Number(sec.value) : null;
        bransSecili.set(m.id, yeni);
        if (yeni) secili.add(yeni);
        dersSecili.set(m.id, secili);
        if (yeni !== m.bransId) baskanSecili.set(m.id, false);
        ciz();
      });
      kutu.append(sec);
      if (brans) {
        const zb = gorevDugmesi('Zümre başkanı (' + dersAd(brans) + ' zümresi)', baskan, () => { baskanSecili.set(m.id, !baskan); ciz(); });
        kutu.append(zb);
      }
      kutu.append(el('h4', 'Verdiği dersler', 'kad-etiket'));
      const cipler = el('div', undefined, 'kad-ciplar');
      for (const d of secenek.dersler) {
        const c = el('button', d.ad, 'kad-cip');
        c.type = 'button';
        c.setAttribute('aria-pressed', String(secili.has(d.id)));
        if (d.id === brans) c.disabled = true;
        c.addEventListener('click', () => {
          if (secili.has(d.id)) secili.delete(d.id); else secili.add(d.id);
          dersSecili.set(m.id, secili);
          c.setAttribute('aria-pressed', String(secili.has(d.id)));
        });
        cipler.append(c);
      }
      kutu.append(cipler);
    }
    b.append(kutu);
  }
  const bitir = () => { dersDuzen = false; dersSecili.clear(); bransSecili.clear(); baskanSecili.clear(); };
  if (!dersDuzen) {
    b.append(kadLink('Düzenle', () => { dersDuzen = true; ciz(); }));
  } else {
    const alt = el('div', undefined, 'kad-alt-dugmeler');
    const kaydet = el('button', 'Kaydet', 'ekle-ac kad-dolu');
    kaydet.type = 'button';
    kaydet.addEventListener('click', async () => {
      kaydet.disabled = true;
      let hepsi = true;
      const dene = async (yol, govde) => {
        const r = await api(yol, { userId: k.id, ...govde });
        if (!r.ok) { hepsi = false; mesaj(r.veri.hata || 'Hata', 'hata'); }
        return r.ok;
      };
      for (const m of uyeler) {
        const brans = bransSecili.has(m.id) ? bransSecili.get(m.id) : m.bransId;
        const baskan = baskanSecili.has(m.id) ? baskanSecili.get(m.id) : m.baskan;
        if (brans && brans !== m.bransId && !await dene('/api/yonetim/kullanici-brans', { uyelikId: m.id, bransId: brans })) break;
        const s = dersSecili.get(m.id);
        if (s && !await dene('/api/yonetim/kullanici-dersler', { uyelikId: m.id, dersIds: [...s] })) break;
        const baskanOnce = brans === m.bransId ? m.baskan : false;
        if (brans && baskan !== baskanOnce && !await dene('/api/yonetim/kullanici-zumre', { uyelikId: m.id, baskan })) break;
      }
      kaydet.disabled = false;
      if (!hepsi) { await yukle(); return; }
      bitir();
      mesaj('Branş ve dersler güncellendi.', 'tamam');
      yukle();
    });
    alt.append(kaydet, kadLink('Vazgeç', () => { bitir(); ciz(); }));
    b.append(alt);
  }

  if (k.atamalar.length) {
    b.append(el('h4', 'Sınıf atamaları', 'kad-etiket'));
    const ul = el('ul', undefined, 'kad-yetki-liste');
    for (const a of k.atamalar) ul.append(el('li', `${a.sinif} · ${a.ders} · haftada ${a.saat} saat`));
    b.append(ul);
  }
  if (k.sinifOgretmenligi.length) for (const etiket of [...new Set(k.sinifOgretmenligi.map(s => s.etiket))]) b.append(el('p', etiket + ': ' + k.sinifOgretmenligi.filter(s => s.etiket === etiket).map(s => s.sinif).join(', '), 'alt'));
  return b;
}

// ---- Durum ----
function durumBolumu() {
  const b = bolum('Okulla ilişki');
  const alt = el('div', undefined, 'kad-alt-dugmeler');
  if (k.kendisi) {
    b.append(el('p', 'Kendi hesabınızı buradan okuldan çıkaramazsınız.', 'alt'));
    return b;
  }
  if (calisiyor()) {
    b.append(el('p', 'Okuldan ayrılan kişi giremez ve derslerden, sınıf öğretmenliğinden alınır; geçmiş kayıtları (not, yoklama, ödev) korunur.', 'alt'));
    alt.append(kadLink('Okuldan ayrıldı olarak işaretle', async () => {
      if (!confirm(`${k.ad} okuldan ayrıldı olarak işaretlensin mi? Giriş yetkisi kapanır, dersleri ve sınıf öğretmenliği boşa alınır.`)) return;
      const r = await api('/api/yonetim/kullanici-ayril', { userId: k.id });
      if (!r.ok) return mesaj(r.veri.hata || 'Hata', 'hata');
      const n = r.veri.boslananDers + r.veri.sinifOgretmenligi;
      await yukle();
      mesaj(n ? `Ayrıldı olarak işaretlendi. ${r.veri.boslananDers} ders ve ${r.veri.sinifOgretmenligi} sınıf öğretmenliği boşta; yenisini atamayı unutmayın.` : 'Ayrıldı olarak işaretlendi.', 'tamam');
    }, 'tehlike'));
  } else {
    b.append(el('p', 'Bu kişi okuldan ayrıldı; giriş yapamaz.', 'alt'));
    alt.append(kadLink('Göreve geri al', async () => sonuc(await api('/api/yonetim/kullanici-geri', { userId: k.id }), 'Kişi göreve geri alındı.')));
  }
  alt.append(kadLink('Kaydı sil', async () => {
    if (!confirm(`${k.ad} kaydı tamamen silinsin mi? Bu işlem geri alınamaz. Geçmişi olan kişi silinemez, ayrıldı olarak işaretleyin.`)) return;
    const r = await api('/api/yonetim/kullanici-sil', { userId: k.id });
    if (!r.ok) return mesaj(r.veri.hata || 'Hata', 'hata');
    location.href = '/kisiler';
  }, 'tehlike'));
  b.append(alt);
  return b;
}

function ciz() {
  const kok = $('dosya');
  kok.replaceChildren(baslik(), kimlikBolumu(), gorevBolumu());
  const d = dersBolumu();
  if (d) kok.append(d);
  kok.append(durumBolumu());
  document.title = 'neademy - ' + k.ad;
}

async function yukle() {
  const r = await api('/api/yonetim/kullanici-detay?id=' + id);
  if (!r.ok) { location.href = '/kisiler'; return; }
  k = r.veri;
  k.roller = k.roller.filter(id => id !== zumreRolu);
  if (gorevDuzen) taslakKur();
  ciz();
}

(async () => {
  if (!id) { location.href = '/kisiler'; return; }
  const s = await api('/api/yonetim/kullanici-secenek');
  if (!s.ok) { location.href = '/panel'; return; }
  secenek = s.veri;
  zumreRolu = secenek.roller.find(r => r.kod === 'zumre')?.id;
  secenek.roller = secenek.roller.filter(r => r.kod !== 'zumre'); // zümre başkanlığı Branş bölümünden verilir
  await yukle();
  const p = new URLSearchParams(location.search);
  if (p.get('yeni')) mesaj('Kişi eklendi. Giriş telefonu ve kimlik numarasıyla giriş yapabilir.', 'tamam');
  else if (p.get('mevcut')) mesaj('Bu kişinin hesabı zaten vardı; yeni görev mevcut hesaba eklendi.', 'tamam');
})();
