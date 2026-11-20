// Öğrenci servisi yönetimi: servis listesi, güzergâh durakları ve öğrencilerin servise bağlanması
let baglam = null;

async function basla() {
  const r = await api('/api/servis/baglam');
  if (!r.ok) return mesaj(r.veri.hata || 'Sayfa açılamadı', 'hata');
  baglam = r.veri;
  const id = sorguAl('id');
  if (id) return detayAc(id);
  sekmeKur($('sekmeler'), [['liste', 'Servisler'], ['servissiz', 'Servissiz öğrenciler']], ad => ad === 'liste' ? listeAc() : servissizAc());
}

// ---------- Liste ----------
async function listeAc() {
  const icerik = $('icerik'); icerik.replaceChildren();
  const arac = el('div', undefined, 'okul-arac');
  const okul = secim([['', 'Tüm okullar'], ...baglam.okullar.map(b => [b.id, b.ad])]);
  if (baglam.okullar.length > 1) arac.append(alan('Okul', okul));
  const yeni = el('button', 'Yeni servis', 'birincil'); yeni.type = 'button';
  yeni.addEventListener('click', () => formAc(null));
  arac.append(yeni);
  icerik.append(arac);
  const sonuc = el('div'); icerik.append(sonuc);
  const yukle = async () => {
    const r = await api('/api/servis/liste?okul=' + okul.value);
    if (!r.ok) return mesaj(r.veri.hata || 'Liste alınamadı', 'hata');
    mesaj('');
    sonuc.replaceChildren();
    const t = r.veri.toplam;
    const k = el('div', undefined, 'sayi-kutulari');
    for (const [s, a] of [[t.ogrenci, 'Öğrenci'], [t.servisli, 'Servisli'], [t.servissiz, 'Servissiz']]) { const d = el('div'); d.append(el('strong', s), a); k.append(d); }
    sonuc.append(k);
    if (!r.veri.servisler.length) return void sonuc.append(bos('Henüz servis eklenmemiş. "Yeni servis" ile başlayın.'));
    const sar = el('div', undefined, 'tablo-sar'); const tb = el('table');
    const bas = el('tr'); for (const h of ['Servis', 'Okul', 'Plaka', 'Şoför', 'Doluluk', 'Durak']) bas.append(el('th', h)); tb.append(bas);
    for (const s of r.veri.servisler) {
      const tr = el('tr', undefined, 'tikla');
      const ad = el('td', s.ad);
      if (!s.aktif) ad.append(' ', el('span', 'Pasif', 'rozet'));
      tr.append(ad, el('td', s.okul), el('td', s.plaka || '-'), el('td', s.soforAd || '-'), el('td', s.kapasite ? `${s.dolu} / ${s.kapasite}` : String(s.dolu)), el('td', String(s.durak)));
      tr.addEventListener('click', () => detayAc(s.id));
      tb.append(tr);
    }
    sar.append(tb); sonuc.append(sar);
  };
  okul.addEventListener('change', yukle);
  yukle();
}

// ---------- Servis formu (ekle / düzenle) ----------
function formAc(s) {
  $('sekmeler').classList.add('gizli');
  const icerik = $('icerik'); icerik.replaceChildren();
  const geri = el('button', '← Geri', 'ikincil kucuk'); geri.type = 'button';
  geri.addEventListener('click', () => s ? detayAc(s.id) : (history.replaceState(null, '', location.pathname), basla()));
  icerik.append(geri, el('h2', s ? 'Servisi düzenle' : 'Yeni servis', 'baslik2'));
  const f = el('form');
  const okul = secim(baglam.okullar.map(b => [b.id, b.ad]), s?.okulId);
  if (!s && baglam.okullar.length > 1) { okul.prepend(Object.assign(el('option', 'Okul seçin'), { value: '' })); okul.value = ''; }
  const ad = girdi('text', s?.ad, { maxLength: 60, required: true, placeholder: 'Servis 1' });
  const plaka = girdi('text', s?.plaka, { maxLength: 12, placeholder: '07 ABC 123' });
  const kap = girdi('number', s?.kapasite ?? '', { min: 0, max: 200, placeholder: 'Boş: sınırsız' });
  const sofor = girdi('text', s?.soforAd, { maxLength: 80 });
  const soforTel = girdi('tel', s?.soforTel, { maxLength: 20, placeholder: '532 123 45 67' });
  const hostes = girdi('text', s?.hostesAd, { maxLength: 80 });
  const hostesTel = girdi('tel', s?.hostesTel, { maxLength: 20 });
  const not = metinAlan(s?.notu, 400);
  const aktif = girdi('checkbox'); aktif.checked = s ? s.aktif : true; aktif.style.width = 'auto';
  const al = el('label', 'Servis aktif'); al.style.display = 'flex'; al.style.gap = '8px'; al.style.alignItems = 'center'; al.prepend(aktif);
  const s1 = el('div', undefined, 'form-satir'); if (!s) s1.append(alan('Okul', okul)); s1.append(alan('Servis adı', ad), alan('Plaka', plaka), alan('Kapasite', kap));
  const s2 = el('div', undefined, 'form-satir'); s2.append(alan('Şoför', sofor), alan('Şoför telefonu', soforTel));
  const s3 = el('div', undefined, 'form-satir'); s3.append(alan('Hostes / rehber', hostes), alan('Hostes telefonu', hostesTel));
  const b = el('button', 'Kaydet', 'birincil'); b.type = 'submit';
  f.append(s1, s2, s3, alan('Not', not), al, b);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    if (!s && !okul.value) return mesaj('Okul seçin', 'hata');
    const r = await api('/api/servis/kaydet', { id: s?.id, okulId: Number(okul.value) || undefined, ad: ad.value, plaka: plaka.value, kapasite: kap.value === '' ? 0 : Number(kap.value),
      soforAd: sofor.value, soforTel: soforTel.value, hostesAd: hostes.value, hostesTel: hostesTel.value, notu: not.value, aktif: aktif.checked });
    if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj('Servis kaydedildi.', 'tamam');
    detayAc(r.veri.id);
  });
  icerik.append(f);
}

// ---------- Servis detayı ----------
async function detayAc(id) {
  const r = await api('/api/servis/detay?id=' + encodeURIComponent(id));
  if (!r.ok) return mesaj(r.veri.hata || 'Servis açılamadı', 'hata');
  const { servis, duraklar, ogrenciler } = r.veri;
  $('sekmeler').classList.add('gizli');
  const icerik = $('icerik'); icerik.replaceChildren();
  const ust = el('div', undefined, 'dugme-sira');
  const geri = el('button', '← Servisler', 'ikincil kucuk'); geri.type = 'button';
  geri.addEventListener('click', () => { history.replaceState(null, '', location.pathname); basla(); });
  const duzenle = el('button', 'Düzenle', 'ikincil kucuk'); duzenle.type = 'button'; duzenle.addEventListener('click', () => formAc(servis));
  const yaz = el('button', 'Yazdır', 'ikincil kucuk'); yaz.type = 'button'; yaz.addEventListener('click', () => window.print());
  const sil = el('button', 'Servisi sil', 'ikincil kucuk tehlike'); sil.type = 'button';
  sil.addEventListener('click', async () => {
    if (!onayla(`${servis.ad} silinsin mi?`)) return;
    const x = await api('/api/servis/sil', { id: servis.id });
    if (!x.ok) return mesaj(x.veri.hata || 'Silinemedi', 'hata');
    history.replaceState(null, '', location.pathname); basla();
  });
  ust.append(geri, duzenle, yaz, sil);
  icerik.append(ust, el('h2', `${servis.ad}${servis.aktif ? '' : ' (pasif)'}`, 'baslik2'));
  const bilgi = el('div', undefined, 'bolum-kutu');
  const satir = (a, v) => { if (v) { const p = el('p'); p.append(el('strong', a + ': '), v); bilgi.append(p); } };
  satir('Okul', servis.okul); satir('Plaka', servis.plaka);
  satir('Şoför', [servis.soforAd, servis.soforTel].filter(Boolean).join(' · '));
  satir('Hostes', [servis.hostesAd, servis.hostesTel].filter(Boolean).join(' · '));
  satir('Doluluk', servis.kapasite ? `${ogrenciler.length} / ${servis.kapasite}` : `${ogrenciler.length} öğrenci`);
  satir('Not', servis.notu);
  icerik.append(bilgi);
  icerik.append(durakBolumu(servis, duraklar, () => detayAc(servis.id)));
  icerik.append(ogrenciBolumu(servis, duraklar, ogrenciler));
  icerik.append(ekleBolumu(servis, duraklar));
}

function durakBolumu(servis, duraklar, yenile) {
  const kutu = el('div', undefined, 'bolum-kutu');
  kutu.append(el('h3', 'Güzergâh durakları', 'baslik2'));
  const liste = duraklar.map(d => ({ ...d }));
  const alanKap = el('div');
  const ciz = () => {
    alanKap.replaceChildren();
    if (!liste.length) alanKap.append(bos('Durak eklenmemiş.'));
    liste.forEach((d, i) => {
      const s = el('div', undefined, 'form-satir');
      const ad = girdi('text', d.ad, { maxLength: 100, placeholder: 'Durak adı' });
      ad.addEventListener('input', () => { d.ad = ad.value; });
      const sb = girdi('time', d.sabahSaat); sb.addEventListener('input', () => { d.sabahSaat = sb.value; });
      const ak = girdi('time', d.aksamSaat); ak.addEventListener('input', () => { d.aksamSaat = ak.value; });
      const arac = el('div', undefined, 'dugme-sira');
      const dugme = (m, fn, dis) => { const b = el('button', m, 'ikincil kucuk'); b.type = 'button'; b.disabled = !!dis; b.addEventListener('click', fn); arac.append(b); };
      dugme('↑', () => { [liste[i - 1], liste[i]] = [liste[i], liste[i - 1]]; ciz(); }, i === 0);
      dugme('↓', () => { [liste[i + 1], liste[i]] = [liste[i], liste[i + 1]]; ciz(); }, i === liste.length - 1);
      dugme('Kaldır', () => { liste.splice(i, 1); ciz(); });
      s.append(alan(`${i + 1}. durak`, ad), alan('Sabah', sb), alan('Akşam', ak), arac);
      alanKap.append(s);
    });
  };
  ciz();
  const alt = el('div', undefined, 'dugme-sira');
  const ekle = el('button', 'Durak ekle', 'ikincil'); ekle.type = 'button';
  ekle.addEventListener('click', () => { liste.push({ ad: '', sabahSaat: '', aksamSaat: '' }); ciz(); });
  const kaydet = el('button', 'Durakları kaydet', 'birincil'); kaydet.type = 'button';
  kaydet.addEventListener('click', async () => {
    const x = await api('/api/servis/duraklar', { servisId: servis.id, duraklar: liste.map(d => ({ id: d.id, ad: d.ad, sabahSaat: d.sabahSaat, aksamSaat: d.aksamSaat })) });
    if (!x.ok) return mesaj(x.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj('Duraklar kaydedildi.', 'tamam'); yenile();
  });
  alt.append(ekle, kaydet);
  kutu.append(alanKap, alt);
  return kutu;
}

function durakSecim(duraklar, deger) {
  const s = secim([['', 'Durak yok'], ...duraklar.map(d => [d.id, d.ad])], deger ?? '');
  return s;
}

function ogrenciBolumu(servis, duraklar, ogrenciler) {
  const kutu = el('div', undefined, 'bolum-kutu');
  kutu.append(el('h3', `Servisteki öğrenciler (${ogrenciler.length})`, 'baslik2'));
  if (!ogrenciler.length) { kutu.append(bos('Bu servise bağlı öğrenci yok.')); return kutu; }
  const sar = el('div', undefined, 'tablo-sar'); const tb = el('table');
  const bas = el('tr'); for (const h of ['Öğrenci', 'Sınıf', 'Durak', 'Yön', '']) bas.append(el('th', h)); tb.append(bas);
  for (const x of ogrenciler) {
    const tr = el('tr');
    const dur = durakSecim(duraklar, x.durakId);
    const yon = secim(Object.entries(baglam.yonler), x.yon);
    const kaydet = async () => {
      const r = await api('/api/servis/ogrenci-guncelle', { ogrenciId: x.id, durakId: Number(dur.value) || null, yon: yon.value });
      mesaj(r.ok ? `${x.ad} güncellendi.` : (r.veri.hata || 'Güncellenemedi'), r.ok ? 'tamam' : 'hata');
    };
    dur.addEventListener('change', kaydet); yon.addEventListener('change', kaydet);
    const cikar = el('button', 'Çıkar', 'ikincil kucuk tehlike'); cikar.type = 'button';
    cikar.addEventListener('click', async () => {
      if (!onayla(`${x.ad} servisten çıkarılsın mı?`)) return;
      const r = await api('/api/servis/cikar', { ogrenciId: x.id });
      if (!r.ok) return mesaj(r.veri.hata || 'Çıkarılamadı', 'hata');
      detayAc(servis.id);
    });
    const td = a => { const t = el('td'); t.append(a); return t; };
    tr.append(el('td', x.ad), el('td', x.sinif || ''), td(dur), td(yon), td(cikar));
    tb.append(tr);
  }
  sar.append(tb); kutu.append(sar);
  return kutu;
}

function ekleBolumu(servis, duraklar) {
  const kutu = el('div', undefined, 'bolum-kutu');
  kutu.append(el('h3', 'Servise öğrenci ekle', 'baslik2'));
  if (!servis.aktif) { kutu.append(bos('Servis pasif; öğrenci eklemek için önce aktif yapın.')); return kutu; }
  const arac = el('div', undefined, 'okul-arac');
  const sinif = secim([['', 'Tüm sınıflar'], ...baglam.siniflar.filter(c => c.okulId === servis.okulId).map(c => [c.id, c.ad])]);
  const ara = girdi('search', '', { placeholder: 'Öğrenci ara', maxLength: 60 });
  const durak = durakSecim(duraklar, '');
  const yon = secim(Object.entries(baglam.yonler), 'cift');
  arac.append(alan('Sınıf', sinif), alan('Ara', ara), alan('Durak', durak), alan('Yön', yon));
  const liste = el('div');
  const secili = new Set();
  const yukle = async () => {
    const r = await api(`/api/servis/servissizler?okul=${servis.okulId}&sinif=${sinif.value}&ara=${encodeURIComponent(ara.value)}`);
    if (!r.ok) return mesaj(r.veri.hata || 'Liste alınamadı', 'hata');
    liste.replaceChildren();
    if (!r.veri.ogrenciler.length) return void liste.append(bos('Servisi olmayan öğrenci bulunamadı.'));
    for (const o of r.veri.ogrenciler) {
      const l = el('label', undefined, 'secenek'); l.style.display = 'flex'; l.style.gap = '8px'; l.style.alignItems = 'center'; l.style.fontWeight = 'normal';
      const c = girdi('checkbox'); c.style.width = 'auto'; c.checked = secili.has(o.id);
      c.addEventListener('change', () => { c.checked ? secili.add(o.id) : secili.delete(o.id); say.textContent = `${secili.size} öğrenci seçili`; });
      l.append(c, `${o.ad}${o.sinif ? ' · ' + o.sinif : ''}`);
      liste.append(l);
    }
  };
  const say = el('span', '0 öğrenci seçili', 'kucuk');
  const ekle = el('button', 'Seçilenleri servise ekle', 'birincil'); ekle.type = 'button';
  ekle.addEventListener('click', async () => {
    if (!secili.size) return mesaj('Önce öğrenci seçin', 'hata');
    const r = await api('/api/servis/ata', { servisId: servis.id, ogrenciIds: [...secili], durakId: Number(durak.value) || null, yon: yon.value });
    if (!r.ok) return mesaj(r.veri.hata || 'Eklenemedi', 'hata');
    mesaj(`${r.veri.eklenen} öğrenci servise eklendi.`, 'tamam');
    detayAc(servis.id);
  });
  sinif.addEventListener('change', yukle);
  let zaman; ara.addEventListener('input', () => { clearTimeout(zaman); zaman = setTimeout(yukle, 300); });
  const alt = el('div', undefined, 'dugme-sira'); alt.append(ekle, say);
  kutu.append(arac, liste, alt);
  yukle();
  return kutu;
}

// ---------- Servissiz öğrenciler ----------
async function servissizAc() {
  const icerik = $('icerik'); icerik.replaceChildren();
  const arac = el('div', undefined, 'okul-arac');
  const okul = secim([['', 'Tüm okullar'], ...baglam.okullar.map(b => [b.id, b.ad])]);
  const sinif = secim([['', 'Tüm sınıflar']]);
  const ara = girdi('search', '', { placeholder: 'Öğrenci ara', maxLength: 60 });
  if (baglam.okullar.length > 1) arac.append(alan('Okul', okul));
  arac.append(alan('Sınıf', sinif), alan('Ara', ara));
  icerik.append(arac, el('p', 'Servis kullanmayan öğrenciler. Bağlamak için ilgili servisin sayfasında "Servise öğrenci ekle" bölümünü kullanın.', 'kucuk'));
  const sonuc = el('div'); icerik.append(sonuc);
  const siniflar = () => {
    const o = Number(okul.value) || 0; const eski = sinif.value;
    sinif.replaceChildren(Object.assign(el('option', 'Tüm sınıflar'), { value: '' }));
    for (const c of baglam.siniflar) if (!o || c.okulId === o) sinif.append(Object.assign(el('option', c.ad), { value: String(c.id) }));
    sinif.value = [...sinif.options].some(x => x.value === eski) ? eski : '';
  };
  const yukle = async () => {
    const r = await api(`/api/servis/servissizler?okul=${okul.value}&sinif=${sinif.value}&ara=${encodeURIComponent(ara.value)}`);
    if (!r.ok) return mesaj(r.veri.hata || 'Liste alınamadı', 'hata');
    sonuc.replaceChildren();
    if (!r.veri.ogrenciler.length) return void sonuc.append(bos('Servissiz öğrenci yok.'));
    const sar = el('div', undefined, 'tablo-sar'); const tb = el('table');
    const bas = el('tr'); for (const h of ['Öğrenci', 'Sınıf']) bas.append(el('th', h)); tb.append(bas);
    for (const x of r.veri.ogrenciler) { const tr = el('tr'); tr.append(el('td', x.ad), el('td', x.sinif)); tb.append(tr); }
    sar.append(tb); sonuc.append(sar);
    if (r.veri.ogrenciler.length >= 300) sonuc.append(el('p', 'İlk 300 öğrenci gösteriliyor; aramayı daraltın.', 'kucuk'));
  };
  okul.addEventListener('change', () => { siniflar(); yukle(); });
  sinif.addEventListener('change', yukle);
  let zaman; ara.addEventListener('input', () => { clearTimeout(zaman); zaman = setTimeout(yukle, 300); });
  siniflar(); yukle();
}

basla();
