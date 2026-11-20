// Rehberlik: görüşme kayıtları, test ve anketler
let baglam = null;
const SORU_TIPLERI = [['likert', 'Likert (5 dereceli)'], ['evet-hayir', 'Evet / Hayır'], ['secenek', 'Çoktan seçmeli'], ['metin', 'Serbest yazı']];
const HEDEFLER = [['ogrenci', 'Öğrenciler'], ['veli', 'Veliler']];
const DURUMLAR = { taslak: 'Taslak', acik: 'Yayında', kapali: 'Kapalı' };

async function basla() {
  const r = await api('/api/rehberlik/baglam');
  if (!r.ok) return mesaj(r.veri.hata || 'Sayfa açılamadı', 'hata');
  baglam = r.veri;
  const ogr = sorguAl('ogrenci');
  if (ogr) return ogrenciDosyasi(ogr);
  const sekmeler = [['gorusme', 'Görüşmeler'], ['form', 'Test ve anketler'], ['takip', `Takipler${baglam.takipler.length ? ' (' + baglam.takipler.length + ')' : ''}`]];
  sekmeKur($('sekmeler'), sekmeler, ad => ({ gorusme: gorusmeAc, form: formlarAc, takip: takipAc }[ad])());
}

const anaSayfa = () => { history.replaceState(null, '', location.pathname); basla(); };

// ====================== Görüşmeler ======================
async function gorusmeAc() {
  const icerik = $('icerik'); icerik.replaceChildren();
  const arac = el('div', undefined, 'okul-arac');
  const okul = secim([['', 'Tüm okullar'], ...baglam.okullar.map(b => [b.id, b.ad])]);
  const ara = girdi('search', '', { placeholder: 'Öğrenci veya konu ara', maxLength: 60 });
  if (baglam.okullar.length > 1) arac.append(alan('Okul', okul));
  arac.append(alan('Ara', ara));
  const yeni = el('button', 'Yeni görüşme', 'birincil'); yeni.type = 'button'; yeni.addEventListener('click', () => gorusmeForm(null, null));
  arac.append(yeni);
  const ozet = el('p', `Son 30 günde ${baglam.ozet.gorusme30} görüşme · ${baglam.ozet.acikFormlar} açık form`, 'kucuk');
  const sonuc = el('div');
  icerik.append(arac, ozet, sonuc);
  const yukle = async () => {
    const r = await api(`/api/rehberlik/gorusmeler?okul=${okul.value}&ara=${encodeURIComponent(ara.value)}`);
    if (!r.ok) return mesaj(r.veri.hata || 'Liste alınamadı', 'hata');
    sonuc.replaceChildren(...gorusmeKartlari(r.veri.gorusmeler, yukle));
  };
  okul.addEventListener('change', yukle);
  let zaman; ara.addEventListener('input', () => { clearTimeout(zaman); zaman = setTimeout(yukle, 300); });
  yukle();
}

function gorusmeKartlari(liste, yenile, ogrenciGoster = true) {
  if (!liste.length) return [bos('Görüşme kaydı yok.')];
  return liste.map(g => {
    const k = el('div', undefined, 'kayit-kart');
    const ust = ogrenciGoster ? `${g.ogrenci}${g.sinif ? ' · ' + g.sinif : ''} — ` : '';
    k.append(el('h3', ust + g.konu));
    k.append(el('p', `${tarihYaz(g.tarih)}${g.saat ? ' ' + g.saat : ''} · ${g.turAd} · ${g.yazan}${g.gizli ? ' · gizli' : ''}`, 'kucuk'));
    if (g.icerikAcik) {
      if (g.ozet) k.append(el('p', g.ozet));
      if (g.yapilan) k.append(el('p', 'Yapılan: ' + g.yapilan));
    } else k.append(el('p', 'Bu görüşmenin içeriği yalnızca yazan kişiye açıktır.', 'kucuk'));
    if (g.takipTarihi) k.append(el('p', `Takip: ${tarihYaz(g.takipTarihi)}${g.takipTamam ? ' (tamamlandı)' : ''}`, 'kucuk'));
    const sira = el('div', undefined, 'dugme-sira');
    const dugme = (m, fn, tehlike) => { const b = el('button', m, 'ikincil kucuk' + (tehlike ? ' tehlike' : '')); b.type = 'button'; b.addEventListener('click', fn); sira.append(b); };
    if (g.takipTarihi) dugme(g.takipTamam ? 'Takibi aç' : 'Takip tamamlandı', async () => {
      const r = await api('/api/rehberlik/gorusme-takip', { id: g.id, tamam: !g.takipTamam });
      if (!r.ok) return mesaj(r.veri.hata || 'Güncellenemedi', 'hata');
      yenile();
    });
    if (ogrenciGoster) dugme('Öğrenci dosyası', () => { history.replaceState(null, '', '?ogrenci=' + g.ogrenciId); basla(); });
    if (g.benim) {
      dugme('Düzenle', () => gorusmeForm(g, null));
      dugme('Sil', async () => {
        if (!onayla('Bu görüşme kaydı silinsin mi?')) return;
        const r = await api('/api/rehberlik/gorusme-sil', { id: g.id });
        if (!r.ok) return mesaj(r.veri.hata || 'Silinemedi', 'hata');
        yenile();
      }, true);
    }
    k.append(sira);
    return k;
  });
}

function gorusmeForm(g, sabitOgrenci) {
  $('sekmeler').classList.add('gizli');
  const icerik = $('icerik'); icerik.replaceChildren();
  const geri = el('button', '← Geri', 'ikincil kucuk'); geri.type = 'button';
  geri.addEventListener('click', () => sabitOgrenci ? ogrenciDosyasi(sabitOgrenci.id) : anaSayfa());
  icerik.append(geri, el('h2', g ? 'Görüşmeyi düzenle' : 'Yeni görüşme', 'baslik2'));
  const f = el('form');
  const ogrenciSec = secim([['', 'Öğrenci seçin']]);
  const ogrKutu = el('div', undefined, 'form-satir');
  const okul = secim([['', 'Tüm okullar'], ...baglam.okullar.map(b => [b.id, b.ad])]);
  const sinif = secim([['', 'Tüm sınıflar']]);
  const ara = girdi('search', '', { placeholder: 'Öğrenci ara', maxLength: 60 });
  if (sabitOgrenci || g) {
    const ad = sabitOgrenci ? sabitOgrenci.ad : g.ogrenci;
    ogrenciSec.replaceChildren(Object.assign(el('option', ad), { value: String(sabitOgrenci ? sabitOgrenci.id : g.ogrenciId) }));
    ogrKutu.append(alan('Öğrenci', ogrenciSec));
  } else {
    if (baglam.okullar.length > 1) ogrKutu.append(alan('Okul', okul));
    ogrKutu.append(alan('Sınıf', sinif), alan('Ara', ara), alan('Öğrenci', ogrenciSec));
    const siniflar = () => {
      const o = Number(okul.value) || 0; const eski = sinif.value;
      sinif.replaceChildren(Object.assign(el('option', 'Tüm sınıflar'), { value: '' }));
      for (const c of baglam.siniflar) if (!o || c.okulId === o) sinif.append(Object.assign(el('option', c.ad), { value: String(c.id) }));
      sinif.value = [...sinif.options].some(x => x.value === eski) ? eski : '';
    };
    const yukle = async () => {
      const r = await api(`/api/rehberlik/ogrenciler?okul=${okul.value}&sinif=${sinif.value}&ara=${encodeURIComponent(ara.value)}`);
      if (!r.ok) return mesaj(r.veri.hata || 'Liste alınamadı', 'hata');
      const secili = ogrenciSec.value;
      ogrenciSec.replaceChildren(Object.assign(el('option', `Öğrenci seçin (${r.veri.ogrenciler.length})`), { value: '' }));
      for (const o of r.veri.ogrenciler) ogrenciSec.append(Object.assign(el('option', `${o.ad}${o.sinif ? ' · ' + o.sinif : ''}`), { value: String(o.id) }));
      if ([...ogrenciSec.options].some(x => x.value === secili)) ogrenciSec.value = secili;
    };
    okul.addEventListener('change', () => { siniflar(); yukle(); }); sinif.addEventListener('change', yukle);
    let zaman; ara.addEventListener('input', () => { clearTimeout(zaman); zaman = setTimeout(yukle, 300); });
    siniflar(); yukle();
  }
  const tarih = girdi('date', g?.tarih || bugunTarih(), { max: bugunTarih(), required: true });
  const saat = girdi('time', g?.saat || '');
  const tur = secim(Object.entries(baglam.turler), g?.tur || 'ogrenci');
  const konu = girdi('text', g?.konu, { maxLength: 150, required: true, placeholder: 'Örn. Sınav kaygısı, sınıf içi uyum' });
  const ozet = metinAlan(g?.ozet, 4000, 5);
  const yapilan = metinAlan(g?.yapilan, 2000, 3);
  const takip = girdi('date', g?.takipTarihi || '');
  const gizli = girdi('checkbox'); gizli.checked = !!g?.gizli; gizli.style.width = 'auto';
  const gl = el('label', 'Gizli görüşme (içeriği yalnızca ben göreyim)'); gl.style.display = 'flex'; gl.style.gap = '8px'; gl.style.alignItems = 'center'; gl.prepend(gizli);
  const s1 = el('div', undefined, 'form-satir'); s1.append(alan('Tarih', tarih), alan('Saat', saat), alan('Görüşülen', tur), alan('Takip tarihi', takip));
  const b = el('button', 'Kaydet', 'birincil'); b.type = 'submit';
  f.append(ogrKutu, s1, alan('Konu', konu), alan('Görüşme özeti', ozet), alan('Yapılan / alınan karar', yapilan), gl, b);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    if (!ogrenciSec.value) return mesaj('Öğrenci seçin', 'hata');
    const r = await api('/api/rehberlik/gorusme', { id: g?.id, ogrenciId: Number(ogrenciSec.value), tarih: tarih.value, saat: saat.value, tur: tur.value, konu: konu.value, ozet: ozet.value, yapilan: yapilan.value, takipTarihi: takip.value, gizli: gizli.checked });
    if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj('Görüşme kaydedildi.', 'tamam');
    if (sabitOgrenci) return ogrenciDosyasi(sabitOgrenci.id);
    if (g) return anaSayfa();
    history.replaceState(null, '', '?ogrenci=' + ogrenciSec.value); basla();
  });
  icerik.append(f);
}

// ====================== Takipler ======================
function takipAc() {
  const icerik = $('icerik'); icerik.replaceChildren();
  icerik.append(el('p', 'Takip tarihi bugün ya da önümüzdeki 7 gün içinde olan, tamamlanmamış görüşmeler.', 'kucuk'));
  const sonuc = el('div'); icerik.append(sonuc);
  const yenile = async () => { await basla0(); };
  async function basla0() { const r = await api('/api/rehberlik/baglam'); if (r.ok) { baglam = r.veri; takipAc(); } }
  sonuc.replaceChildren(...(baglam.takipler.length ? gorusmeKartlari(baglam.takipler, yenile) : [bos('Bekleyen takip yok.')]));
}

// ====================== Öğrenci dosyası ======================
async function ogrenciDosyasi(id) {
  const r = await api('/api/rehberlik/ogrenci?id=' + encodeURIComponent(id));
  if (!r.ok) { mesaj(r.veri.hata || 'Öğrenci açılamadı', 'hata'); return anaSayfa(); }
  mesaj('');
  const { ogrenci, gorusmeler, sonuclar } = r.veri;
  $('sekmeler').classList.add('gizli');
  const icerik = $('icerik'); icerik.replaceChildren();
  const geri = el('button', '← Rehberlik', 'ikincil kucuk'); geri.type = 'button'; geri.addEventListener('click', anaSayfa);
  icerik.append(geri, el('h2', `${ogrenci.ad}${ogrenci.sinif ? ' · ' + ogrenci.sinif : ''}`, 'baslik2'));
  const yeni = el('button', 'Yeni görüşme', 'birincil'); yeni.type = 'button'; yeni.addEventListener('click', () => gorusmeForm(null, ogrenci));
  icerik.append(yeni);
  const kutu = el('div', undefined, 'bolum-kutu'); kutu.append(el('h3', 'Görüşmeler', 'baslik2'));
  kutu.append(...gorusmeKartlari(gorusmeler, () => ogrenciDosyasi(id), false));
  icerik.append(kutu);
  const k2 = el('div', undefined, 'bolum-kutu'); k2.append(el('h3', 'Test ve anket sonuçları', 'baslik2'));
  if (!sonuclar.length) k2.append(bos('Cevaplanmış test ya da anket yok.'));
  else {
    const sar = el('div', undefined, 'tablo-sar'); const tb = el('table');
    const bas = el('tr'); for (const h of ['Form', 'Tür', 'Puan', 'Yorum', 'Tarih']) bas.append(el('th', h)); tb.append(bas);
    for (const s of sonuclar) {
      const tr = el('tr'); tr.append(el('td', s.ad), el('td', s.tur === 'test' ? 'Test' : 'Anket'), el('td', s.puan === null ? '-' : `${s.puan} / ${s.enYuksek}`), el('td', s.yorum || '-'), el('td', tarihYaz(s.tarih)));
      tb.append(tr);
    }
    sar.append(tb); k2.append(sar);
  }
  icerik.append(k2);
}

// ====================== Test ve anketler ======================
async function formlarAc() {
  const icerik = $('icerik'); icerik.replaceChildren();
  const arac = el('div', undefined, 'okul-arac');
  const yeni = el('button', 'Yeni test / anket', 'birincil'); yeni.type = 'button'; yeni.addEventListener('click', () => formForm(null));
  arac.append(yeni); icerik.append(arac);
  const sonuc = el('div'); icerik.append(sonuc);
  const yukle = async () => {
    const r = await api('/api/rehberlik/formlar');
    if (!r.ok) return mesaj(r.veri.hata || 'Liste alınamadı', 'hata');
    sonuc.replaceChildren();
    if (!r.veri.formlar.length) return void sonuc.append(bos('Henüz test ya da anket yok. Öğrencilere ya da velilere yönelik bir form oluşturabilirsiniz.'));
    for (const f of r.veri.formlar) {
      const k = el('div', undefined, 'kayit-kart');
      k.append(el('h3', f.ad));
      k.append(el('p', [f.tur === 'test' ? 'Test' : 'Anket', f.hedef === 'veli' ? 'Veliler' : 'Öğrenciler', baglam.okullar.length > 1 ? f.okul : '', DURUMLAR[f.durum], `${f.soruSayisi} soru`, `${f.cevapSayisi} cevap`, f.sonTarih ? 'Son: ' + tarihYaz(f.sonTarih) : '', f.anonim ? 'anonim' : ''].filter(Boolean).join(' · '), 'kucuk'));
      const sira = el('div', undefined, 'dugme-sira');
      const dugme = (m, fn, tehlike) => { const b = el('button', m, 'ikincil kucuk' + (tehlike ? ' tehlike' : '')); b.type = 'button'; b.addEventListener('click', fn); sira.append(b); };
      dugme('Sonuçlar', () => sonucAc(f.id));
      dugme('Düzenle', () => formForm(f.id));
      const durum = async d => { const x = await api('/api/rehberlik/form-durum', { id: f.id, durum: d }); if (!x.ok) return mesaj(x.veri.hata || 'Güncellenemedi', 'hata'); mesaj(''); yukle(); };
      if (f.durum !== 'acik') dugme('Yayınla', () => durum('acik'));
      if (f.durum === 'acik') dugme('Kapat', () => durum('kapali'));
      if (f.durum === 'kapali' && !f.cevapSayisi) dugme('Taslağa al', () => durum('taslak'));
      dugme('Sil', async () => {
        if (!onayla(`"${f.ad}" ve ${f.cevapSayisi} cevabı silinsin mi?`)) return;
        const x = await api('/api/rehberlik/form-sil', { id: f.id });
        if (!x.ok) return mesaj(x.veri.hata || 'Silinemedi', 'hata');
        yukle();
      }, true);
      k.append(sira); sonuc.append(k);
    }
  };
  yukle();
}

async function formForm(id) {
  let form = { tur: 'anket', ad: '', aciklama: '', hedef: 'ogrenci', sinifIds: [], sorular: [], yorumlar: [], anonim: false, sonucGoster: false, sonTarih: '', okulId: baglam.okullar.length === 1 ? baglam.okullar[0].id : null };
  if (id) {
    const r = await api('/api/rehberlik/form?id=' + id);
    if (!r.ok) return mesaj(r.veri.hata || 'Form açılamadı', 'hata');
    form = r.veri.form;
  }
  mesaj('');
  $('sekmeler').classList.add('gizli');
  const icerik = $('icerik'); icerik.replaceChildren();
  const geri = el('button', '← Geri', 'ikincil kucuk'); geri.type = 'button'; geri.addEventListener('click', anaSayfa);
  icerik.append(geri, el('h2', id ? 'Formu düzenle' : 'Yeni test / anket', 'baslik2'));
  const f = el('form');
  const tur = secim([['anket', 'Anket (puansız)'], ['test', 'Test (puanlı)']], form.tur);
  const okul = secim(baglam.okullar.map(b => [b.id, b.ad]), form.okulId);
  if (!id && baglam.okullar.length > 1) { okul.prepend(Object.assign(el('option', 'Okul seçin'), { value: '' })); okul.value = ''; }
  const hedef = secim(HEDEFLER, form.hedef);
  const ad = girdi('text', form.ad, { maxLength: 120, required: true });
  const aciklama = metinAlan(form.aciklama, 800, 2);
  const sonTarih = girdi('date', form.sonTarih || '');
  const anonim = girdi('checkbox'); anonim.checked = form.anonim; anonim.style.width = 'auto';
  const sonucGoster = girdi('checkbox'); sonucGoster.checked = form.sonucGoster; sonucGoster.style.width = 'auto';
  const kutuEtiket = (m, c) => { const l = el('label', m); l.style.display = 'flex'; l.style.gap = '8px'; l.style.alignItems = 'center'; l.prepend(c); return l; };
  const anonimL = kutuEtiket('Anonim (cevaplar isimsiz gösterilir)', anonim);
  const sonucL = kutuEtiket('Test bitince puan ve yorumu cevaplayana göster', sonucGoster);

  const s1 = el('div', undefined, 'form-satir');
  s1.append(alan('Tür', tur)); if (!id && baglam.okullar.length > 1) s1.append(alan('Okul', okul)); s1.append(alan('Kime', hedef), alan('Son tarih', sonTarih));

  // Sınıflar
  const sinifKutu = el('div'); const sinifSecili = new Set(form.sinifIds);
  const sinifCiz = () => {
    sinifKutu.replaceChildren();
    const o = Number(okul.value) || form.okulId || 0;
    const liste = baglam.siniflar.filter(c => c.okulId === o);
    if (!o) return void sinifKutu.append(el('p', 'Önce okul seçin.', 'kucuk'));
    sinifKutu.append(el('p', 'Hedef sınıflar (hiçbiri seçilmezse okulun tüm sınıfları):', 'kucuk'));
    for (const c of liste) {
      const cb = girdi('checkbox'); cb.checked = sinifSecili.has(c.id); cb.style.width = 'auto';
      cb.addEventListener('change', () => { cb.checked ? sinifSecili.add(c.id) : sinifSecili.delete(c.id); });
      const l = el('label', c.ad); l.style.display = 'inline-flex'; l.style.gap = '6px'; l.style.marginRight = '14px'; l.style.alignItems = 'center'; l.style.fontWeight = 'normal'; l.prepend(cb);
      sinifKutu.append(l);
    }
  };
  okul.addEventListener('change', () => { sinifSecili.clear(); sinifCiz(); });
  sinifCiz();

  // Sorular
  const sorular = form.sorular.map(s => ({ ...s, secenekler: s.secenekler ? s.secenekler.map(x => ({ ...x })) : [] }));
  const soruKap = el('div');
  const soruCiz = () => {
    soruKap.replaceChildren();
    const test = tur.value === 'test';
    if (!sorular.length) soruKap.append(bos('Henüz soru yok.'));
    sorular.forEach((s, i) => {
      const kutu = el('div', undefined, 'soru-kutu');
      const metin = girdi('text', s.metin, { maxLength: 300, placeholder: `${i + 1}. soru` });
      metin.addEventListener('input', () => { s.metin = metin.value; });
      const tip = secim(SORU_TIPLERI.filter(([k]) => !(test && k === 'metin')), s.tip);
      tip.addEventListener('change', () => { s.tip = tip.value; if (s.tip === 'secenek' && s.secenekler.length < 2) s.secenekler = [{ metin: '', puan: 0 }, { metin: '', puan: 0 }]; soruCiz(); });
      const satir = el('div', undefined, 'form-satir'); satir.append(alan('Soru', metin), alan('Tür', tip));
      kutu.append(satir);
      if (s.tip === 'secenek') {
        s.secenekler.forEach((x, j) => {
          const sr = el('div', undefined, 'form-satir');
          const sm = girdi('text', x.metin, { maxLength: 120, placeholder: `${j + 1}. seçenek` }); sm.addEventListener('input', () => { x.metin = sm.value; });
          sr.append(alan(`Seçenek ${j + 1}`, sm));
          if (test) { const sp = girdi('number', x.puan, { min: -100, max: 100 }); sp.addEventListener('input', () => { x.puan = Number(sp.value) || 0; }); sr.append(alan('Puan', sp)); }
          const sil = el('button', 'Kaldır', 'ikincil kucuk'); sil.type = 'button'; sil.disabled = s.secenekler.length <= 2;
          sil.addEventListener('click', () => { s.secenekler.splice(j, 1); soruCiz(); }); sr.append(sil);
          kutu.append(sr);
        });
        const ek = el('button', 'Seçenek ekle', 'ikincil kucuk'); ek.type = 'button'; ek.disabled = s.secenekler.length >= 10;
        ek.addEventListener('click', () => { s.secenekler.push({ metin: '', puan: 0 }); soruCiz(); }); kutu.append(ek);
      }
      if (test && (s.tip === 'likert' || s.tip === 'evet-hayir')) {
        const ters = girdi('checkbox'); ters.checked = !!s.ters; ters.style.width = 'auto'; ters.addEventListener('change', () => { s.ters = ters.checked; });
        kutu.append(kutuEtiket(s.tip === 'likert' ? 'Ters puanlanan soru (5 → 1)' : 'Puan "Hayır" cevabına verilir', ters));
      }
      const arac = el('div', undefined, 'dugme-sira');
      const d = (m, fn, dis, th) => { const b = el('button', m, 'ikincil kucuk' + (th ? ' tehlike' : '')); b.type = 'button'; b.disabled = !!dis; b.addEventListener('click', fn); arac.append(b); };
      d('↑', () => { [sorular[i - 1], sorular[i]] = [sorular[i], sorular[i - 1]]; soruCiz(); }, i === 0);
      d('↓', () => { [sorular[i + 1], sorular[i]] = [sorular[i], sorular[i + 1]]; soruCiz(); }, i === sorular.length - 1);
      d('Soruyu sil', () => { sorular.splice(i, 1); soruCiz(); }, false, true);
      kutu.append(arac); soruKap.append(kutu);
    });
  };
  const soruEkle = el('button', 'Soru ekle', 'ikincil'); soruEkle.type = 'button';
  soruEkle.addEventListener('click', () => { sorular.push({ metin: '', tip: 'likert', secenekler: [], ters: false }); soruCiz(); });

  // Puan aralıkları (test)
  const yorumlar = form.yorumlar.map(y => ({ ...y }));
  const yorumKutu = el('div', undefined, 'bolum-kutu');
  const yorumCiz = () => {
    yorumKutu.replaceChildren();
    const test = tur.value === 'test';
    yorumKutu.classList.toggle('gizli', !test);
    if (!test) return;
    yorumKutu.append(el('h3', 'Puan aralıkları ve yorumlar', 'baslik2'));
    yorumKutu.append(el('p', 'Toplam puana göre cevaplayana gösterilecek başlık ve açıklama.', 'kucuk'));
    yorumlar.forEach((y, i) => {
      const s = el('div', undefined, 'form-satir');
      const mn = girdi('number', y.min, { step: 'any' }); mn.addEventListener('input', () => { y.min = Number(mn.value); });
      const mx = girdi('number', y.max, { step: 'any' }); mx.addEventListener('input', () => { y.max = Number(mx.value); });
      const bs = girdi('text', y.baslik, { maxLength: 80 }); bs.addEventListener('input', () => { y.baslik = bs.value; });
      const ac = metinAlan(y.aciklama, 400, 2); ac.addEventListener('input', () => { y.aciklama = ac.value; });
      const sil = el('button', 'Kaldır', 'ikincil kucuk tehlike'); sil.type = 'button'; sil.addEventListener('click', () => { yorumlar.splice(i, 1); yorumCiz(); });
      s.append(alan('En az puan', mn), alan('En çok puan', mx), alan('Başlık', bs), alan('Açıklama', ac), sil);
      yorumKutu.append(s);
    });
    const ek = el('button', 'Aralık ekle', 'ikincil kucuk'); ek.type = 'button';
    ek.addEventListener('click', () => { yorumlar.push({ min: 0, max: 0, baslik: '', aciklama: '' }); yorumCiz(); });
    yorumKutu.append(ek);
  };

  const turDegisti = () => {
    const test = tur.value === 'test';
    anonimL.classList.toggle('gizli', test); sonucL.classList.toggle('gizli', !test);
    if (test) { for (let i = sorular.length - 1; i >= 0; i--) if (sorular[i].tip === 'metin') sorular.splice(i, 1); }
    soruCiz(); yorumCiz();
  };
  tur.addEventListener('change', turDegisti);
  turDegisti();

  const b = el('button', 'Kaydet', 'birincil'); b.type = 'submit';
  f.append(s1, alan('Başlık', ad), alan('Açıklama (cevaplayana gösterilir)', aciklama), sinifKutu, anonimL, sonucL, el('h3', 'Sorular', 'baslik2'), soruKap, soruEkle, yorumKutu, b);
  f.addEventListener('submit', async e => {
    e.preventDefault();
    if (!id && !okul.value) return mesaj('Okul seçin', 'hata');
    const test = tur.value === 'test';
    const r = await api('/api/rehberlik/form-kaydet', {
      id, tur: tur.value, okulId: Number(okul.value) || form.okulId, ad: ad.value, aciklama: aciklama.value, hedef: hedef.value, sinifIds: [...sinifSecili], sonTarih: sonTarih.value,
      anonim: !test && anonim.checked, sonucGoster: test && sonucGoster.checked,
      sorular: sorular.map(s => ({ metin: s.metin, tip: s.tip, secenekler: s.tip === 'secenek' ? s.secenekler : undefined, ters: test ? !!s.ters : undefined })),
      yorumlar: test ? yorumlar : [],
    });
    if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj(id ? 'Form güncellendi.' : 'Form taslak olarak kaydedildi. Hazır olunca "Yayınla" ile öğrencilere/velilere açın.', 'tamam');
    anaSayfa();
  });
  icerik.append(f);
}

// ====================== Sonuçlar ======================
async function sonucAc(id) {
  const r = await api('/api/rehberlik/form-sonuc?id=' + id);
  if (!r.ok) return mesaj(r.veri.hata || 'Sonuçlar alınamadı', 'hata');
  mesaj('');
  const d = r.veri;
  $('sekmeler').classList.add('gizli');
  const icerik = $('icerik'); icerik.replaceChildren();
  const ust = el('div', undefined, 'dugme-sira');
  const geri = el('button', '← Test ve anketler', 'ikincil kucuk'); geri.type = 'button'; geri.addEventListener('click', anaSayfa);
  const yaz = el('button', 'Yazdır', 'ikincil kucuk'); yaz.type = 'button'; yaz.addEventListener('click', () => window.print());
  ust.append(geri, yaz);
  icerik.append(ust, el('h2', d.form.ad, 'baslik2'));
  const sk = el('div', undefined, 'sayi-kutulari');
  const kutu = (s, a) => { const x = el('div'); x.append(el('strong', s), a); sk.append(x); };
  kutu(d.cevapSayisi, 'Cevap'); kutu(`${d.katilanOgrenci} / ${d.beklenen}`, 'Katılım');
  if (d.form.tur === 'test') kutu(d.ortalamaPuan ?? '-', `Ortalama puan (en çok ${d.enYuksek})`);
  icerik.append(sk);
  if (d.yorumDagilimi?.length) {
    const k = el('div', undefined, 'bolum-kutu'); k.append(el('h3', 'Yorum dağılımı', 'baslik2'));
    for (const y of d.yorumDagilimi) k.append(el('p', `${y.baslik}: ${y.sayi} kişi`));
    icerik.append(k);
  }
  const sk2 = el('div', undefined, 'bolum-kutu'); sk2.append(el('h3', 'Soru bazında sonuçlar', 'baslik2'));
  d.sorularSonuc.forEach((s, i) => {
    const k = el('div', undefined, 'kayit-kart'); k.append(el('h3', `${i + 1}. ${s.metin}`));
    if (s.tip === 'metin') {
      if (!s.yanitlar.length) k.append(el('p', 'Yazılı cevap yok.', 'kucuk'));
      for (const y of s.yanitlar) k.append(el('p', '• ' + y));
    } else {
      const toplam = s.dagilim.reduce((t, x) => t + x.sayi, 0) || 1;
      for (const x of s.dagilim) {
        const satir = el('div'); satir.style.cssText = 'display:grid;grid-template-columns:minmax(120px,1fr) 2fr 60px;gap:8px;align-items:center;margin:3px 0';
        const cubuk = el('div'); cubuk.style.cssText = `height:10px;background:var(--border);border-radius:5px;overflow:hidden`;
        const dolu = el('div'); dolu.style.cssText = `height:100%;width:${Math.round(x.sayi / toplam * 100)}%;background:var(--accent, #1f3a63)`; cubuk.append(dolu);
        satir.append(el('span', x.etiket), cubuk, el('span', String(x.sayi))); k.append(satir);
      }
      if (s.ortalama !== undefined) k.append(el('p', `Ortalama: ${s.ortalama} / 5`, 'kucuk'));
    }
    sk2.append(k);
  });
  icerik.append(sk2);
  if (d.form.anonim) { icerik.append(el('p', 'Bu anket anonim olduğu için kişi bazında sonuç gösterilmez.', 'bos-not')); return; }

  const kk = el('div', undefined, 'bolum-kutu'); kk.append(el('h3', 'Cevaplayanlar', 'baslik2'));
  if (!d.kisiler.length) kk.append(bos('Henüz cevap yok.'));
  else {
    const sar = el('div', undefined, 'tablo-sar'); const tb = el('table');
    const bas = el('tr'); for (const h of ['Öğrenci', 'Sınıf', 'Puan', 'Yorum', 'Tarih', '']) bas.append(el('th', h)); tb.append(bas);
    for (const k of d.kisiler) {
      const tr = el('tr'); tr.append(el('td', k.ad), el('td', k.sinif), el('td', k.puan === null ? '-' : `${k.puan} / ${d.enYuksek}`), el('td', k.yorum || '-'), el('td', tarihYaz(k.tarih)));
      const td = el('td'); const sil = el('button', 'Cevabı sil', 'ikincil kucuk tehlike'); sil.type = 'button';
      sil.addEventListener('click', async () => {
        if (!onayla(`${k.ad} öğrencisinin cevabı silinsin mi?`)) return;
        const x = await api('/api/rehberlik/cevap-sil', { id: k.cevapId });
        if (!x.ok) return mesaj(x.veri.hata || 'Silinemedi', 'hata');
        sonucAc(id);
      });
      td.append(sil); tr.append(td); tb.append(tr);
    }
    sar.append(tb); kk.append(sar);
  }
  icerik.append(kk);

  const kb = el('div', undefined, 'bolum-kutu'); kb.append(el('h3', `Henüz cevaplamayanlar (${d.cevaplamayanlar.length})`, 'baslik2'));
  if (!d.cevaplamayanlar.length) kb.append(bos('Herkes cevapladı.'));
  else {
    kb.append(el('p', 'Kâğıt üzerinde uygulanan formlarda cevabı sizin girmeniz için adın yanındaki düğmeyi kullanın.', 'kucuk'));
    for (const k of d.cevaplamayanlar) {
      const sira = el('div', undefined, 'dugme-sira');
      const ad = el('span', `${k.ad}${k.sinif ? ' · ' + k.sinif : ''}`); ad.style.minWidth = '200px';
      const gir = el('button', 'Adına cevap gir', 'ikincil kucuk'); gir.type = 'button';
      gir.addEventListener('click', () => cevapGir(d, k));
      sira.append(ad, gir); kb.append(sira);
    }
  }
  icerik.append(kb);
}

function cevapGir(d, ogr) {
  const icerik = $('icerik'); icerik.replaceChildren();
  const geri = el('button', '← Sonuçlara dön', 'ikincil kucuk'); geri.type = 'button'; geri.addEventListener('click', () => sonucAc(d.form.id));
  icerik.append(geri, el('h2', `${d.form.ad} — ${ogr.ad}`, 'baslik2'));
  const fm = el('form'); const okuyucular = [];
  d.form.sorular.forEach((s, i) => {
    const kutu = el('fieldset', undefined, 'soru-kutu'); kutu.append(el('legend', `${i + 1}. ${s.metin}`));
    if (s.tip === 'metin') { const t = metinAlan('', 500, 2); kutu.append(t); okuyucular.push(() => t.value.trim() || null); }
    else {
      const etiketler = s.tip === 'likert' ? baglam.likert : s.tip === 'evet-hayir' ? ['Evet', 'Hayır'] : s.secenekler.map(x => x.metin);
      const ad = 'g' + i;
      etiketler.forEach((m, j) => { const l = el('label', undefined, 'secenek'); l.append(girdi('radio', String(s.tip === 'likert' ? j + 1 : j), { name: ad }), m); kutu.append(l); });
      okuyucular.push(() => { const x = fm.querySelector(`input[name="${ad}"]:checked`); return x ? Number(x.value) : null; });
    }
    fm.append(kutu);
  });
  const b = el('button', 'Cevabı kaydet', 'birincil'); b.type = 'submit'; fm.append(b);
  fm.addEventListener('submit', async e => {
    e.preventDefault();
    const cevaplar = okuyucular.map(o => o());
    const eksik = d.form.sorular.findIndex((s, i) => s.tip !== 'metin' && cevaplar[i] === null);
    if (eksik >= 0) return mesaj(`${eksik + 1}. soruyu işaretleyin`, 'hata');
    const r = await api('/api/rehberlik/cevap-gir', { formId: d.form.id, ogrenciId: ogr.ogrenciId, cevaplar });
    if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
    mesaj(r.veri.sonuc?.puan != null ? `Cevap kaydedildi. Puan: ${r.veri.sonuc.puan}${r.veri.sonuc.yorum ? ' — ' + r.veri.sonuc.yorum.baslik : ''}` : 'Cevap kaydedildi.', 'tamam');
    sonucAc(d.form.id);
  });
  icerik.append(fm);
}

basla();
