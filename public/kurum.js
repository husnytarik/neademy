// Okul kurulumu: kurum profili, kampüsler, okullar ve okul yöneticileri.
// Düz düzen: liste → okul sayfası → tek amaçlı form sayfaları (#gorunum/id ile gezilir).
(() => {
  const { el, telYaz, logoUrl, rota, git, kart, baslik, geri, ust, satir, altBaslik, dugme, eylem, bosNot, bilgi, tanitim, okulBilgisi } = KD;
  const kok = document.getElementById('kurum-bolum');
  let v = null;

  let mesajTut = false; // yazma işleminden sonraki sayfa değişiminde başarı mesajı silinmesin
  const mesaj = (metin, tur = '') => { const m = document.getElementById('mesaj'); m.textContent = metin; m.className = 'mesaj ' + tur; mesajTut = !!metin; };
  const logo = (ad, url) => avatarYap(ad, url, 'orta logo');

  async function api(yol, govde) {
    const r = await fetch(yol, govde === undefined ? {} : { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(govde) });
    if (r.status === 401) { location.href = '/'; throw new Error('oturum'); }
    if (r.status === 403 && govde === undefined) { location.href = '/panel'; throw new Error('yetki'); }
    return { ok: r.ok, veri: await r.json().catch(() => ({})) };
  }
  // Yazma işlemi: hata ya da başarı mesajı gösterip veriyi yeniler, sonra hedefe gider
  async function yap(yol, govde, basari, hedef) {
    const r = await api(yol, govde);
    if (!r.ok) { mesaj(r.veri.hata || 'İşlem yapılamadı', 'hata'); return null; }
    await yukle(false);
    mesaj(basari, 'tamam');
    if (hedef) git(hedef(r.veri)); else ciz();
    return r;
  }

  // ---- Form parçaları ----
  function alan(etiket, kontrol, id) {
    kontrol.id = id;
    const l = el('label', etiket); l.htmlFor = id;
    const kap = document.createElement('div');
    kap.append(l, kontrol);
    return kap;
  }
  const girdi = (deger, ek = {}) => Object.assign(el('input'), { value: deger || '', maxLength: 200 }, ek);
  const secenek = (sel, liste) => { for (const [d, e] of liste) sel.append(Object.assign(el('option', e), { value: d })); return sel; };
  const satirlar = (...a) => { const s = el('div', undefined, 'form-satir'); s.append(...a); return s; };

  // Tanıtım alanları: web sitesi, hakkında yazısı, sosyal medya hesapları
  function tanitimAlanlari(n, onek) {
    const web = girdi(n?.web, { maxLength: 100, placeholder: 'ornek.com' });
    const acik = Object.assign(el('textarea'), { value: n?.aciklama || '', maxLength: v.tanitimAzami, rows: 5, placeholder: 'Velilerin ve öğrencilerin okuyacağı kısa tanıtım yazısı' });
    const hesaplar = v.sosyalAlanlar.map(a => [a.kod, a.ad, girdi(n?.sosyal?.[a.kod], { maxLength: 200, placeholder: '@kullanıcı ya da bağlantı' })]);
    const dugumler = [alan('Web sitesi', web, onek + '-web'), alan('Hakkında', acik, onek + '-acik'),
      ...hesaplar.map(([k, ad, g]) => alan(ad, g, `${onek}-s-${k}`))];
    const oku = () => ({ web: web.value, aciklama: acik.value, sosyal: Object.fromEntries(hesaplar.map(([k, , g]) => [k, g.value])) });
    return { dugumler, oku };
  }

  // Logo seçici: dosyayı yuvarlak çerçevede kırptırır (PNG, 512 px); kaydedilene dek yalnızca bellekte tutulur
  function logoSecici(ad, mevcutUrl) {
    const kap = el('div', undefined, 'logo-sec');
    const onizleme = el('span');
    onizleme.append(logo(ad, mevcutUrl));
    const dosya = el('input'); dosya.type = 'file'; dosya.accept = 'image/jpeg,image/png,image/webp'; dosya.hidden = true;
    const dugmeEl = el('button', mevcutUrl ? 'Logoyu değiştir' : 'Logo seç', 'ikincil'); dugmeEl.type = 'button';
    dugmeEl.addEventListener('click', () => dosya.click());
    const sec = { blob: null, kap };
    dosya.addEventListener('change', async () => {
      const f = dosya.files[0];
      dosya.value = '';
      if (!f) return;
      try {
        const k = await fotoKirp(f, { tur: 'png', kenar: 512, baslik: 'Logoyu ayarlayın' });
        if (!k) return;
        sec.blob = k.blob;
        const av = el('span', undefined, 'ogr-avatar orta logo');
        av.append(k.tuval);
        onizleme.replaceChildren(av);
        dugmeEl.textContent = 'Logoyu değiştir';
      } catch { mesaj('Logo okunamadı; başka bir görsel deneyin.', 'hata'); }
    });
    kap.append(onizleme, dugmeEl, dosya);
    return sec;
  }
  async function logoYukle(yol, blob) {
    const y = await fetch(yol, { method: 'POST', headers: { 'Content-Type': blob.type }, body: blob });
    return y.ok ? null : ((await y.json().catch(() => ({}))).hata || 'Logo yüklenemedi');
  }
  const tehlike = (metin, fn) => { const b = el('button', metin, 'kd-tehlike'); b.type = 'button'; b.addEventListener('click', fn); return b; };
  const cubuk = geriHedef => {
    const k = el('div', undefined, 'kd-cubuk');
    const kaydet = el('button', 'Kaydet', 'kd-dugme'); kaydet.type = 'submit';
    k.append(dugme('Vazgeç', 'hafif', geriHedef), kaydet);
    return k;
  };
  // Sekmeli form: her sekme bir panel. Gizli panelde geçersiz alan olursa o sekme açılır.
  // Kurucu ekleme sayfasından dönülürken 'Kurucu' sekmesi açık gelsin diye sekme adı önceden bırakılabilir.
  let acilacakSekme = null;
  function sekmeliForm(f, sekmeler) {
    const bar = el('div', undefined, 'sekmeler'); bar.setAttribute('role', 'group');
    const dugmeler = [], paneller = [];
    const ac = i => sekmeler.forEach((_, j) => { dugmeler[j].setAttribute('aria-pressed', String(i === j)); paneller[j].hidden = i !== j; });
    for (const [ad, dugumler] of sekmeler) {
      const b = el('button', ad); b.type = 'button';
      b.addEventListener('click', () => ac(dugmeler.indexOf(b)));
      const p = el('div', undefined, 'kd-panel'); p.append(...dugumler);
      dugmeler.push(b); paneller.push(p); bar.append(b);
    }
    f.append(bar, ...paneller);
    f.addEventListener('invalid', e => { const i = paneller.findIndex(p => p.contains(e.target)); if (i >= 0) ac(i); }, true);
    ac(Math.max(0, sekmeler.findIndex(([ad]) => ad === acilacakSekme)));
    acilacakSekme = null;
  }
  // Form sayfası: geri bağlantısı + başlık + tek kart
  function formSayfasi(geriMetin, geriHedef, baslikMetni, form, alt) {
    kok.append(geri(geriMetin, geriHedef), kart(ust({ ad: baslikMetni, alt }), form));
  }

  // ---- Görünümler ----
  // Ana sayfa: üstte Kurum ve kampüs sekmeleri; seçili sekmenin içeriği altta
  function liste() {
    const { g, id } = rota();
    const kampus = g === 'kampus' ? v.kampusler.find(c => c.id === id) : null;
    const bar = el('div', undefined, 'sekmeler kd-ana-sekme'); bar.setAttribute('role', 'group');
    const sek = (metin, hedef, basili) => {
      const b = el('button', metin); b.type = 'button'; b.setAttribute('aria-pressed', String(basili));
      b.addEventListener('click', () => git(hedef)); bar.append(b); return b;
    };
    sek('Kurum', '#', !kampus);
    for (const c of v.kampusler) sek(c.ad.replace(/\s+kampüsü$/i, '') || c.ad, '#kampus/' + c.id, kampus?.id === c.id);
    if (v.kurumYonetimi) sek('+ Kampüs', '#kampus-yeni', false).classList.add('ekle');
    kok.append(bar);
    // Çok kampüs olunca sekme çubuğu yana kaydırılır; seçili sekme görünür kalsın
    const secili = bar.querySelector('[aria-pressed="true"]');
    if (secili) bar.scrollLeft += secili.getBoundingClientRect().left - bar.getBoundingClientRect().left - (bar.clientWidth - secili.offsetWidth) / 2;
    if (kampus) kampusSekmesi(kampus); else kurumSekmesi();
  }

  function kurumSekmesi() {
    const k = v.kurum;
    const duz = v.kurumYonetimi ? dugme('Düzenle', 'hafif kucuk', '#kurum-duzenle') : null;
    const kt = kart(
      ust({ avatar: logo(k.ad, v.logo ? `/api/kurum-logo?v=${v.logo}` : null), ad: k.ad, alt: k.kisaAd || 'Kısa ad girilmedi', eylem: duz }),
      bilgi([['Telefon', telYaz(k.telefon)], ['E-posta', k.eposta], ['Web', k.web], ['Adres', k.adres]], null),
    );
    const tn = tanitim(k);
    if (tn) kt.append(tn);
    if (v.kurucular.length) {
      kt.append(altBaslik('Kurucu'));
      for (const c of v.kurucular) kt.append(satir({ avatar: avatarYap(c.ad, c.foto, 'kucuk'), ad: c.ad, alt: 'Kurucu' }));
    }
    kok.append(kt);
    if (!v.kampusler.length) kok.append(bosNot('Henüz kampüs eklenmedi. Kampüs sayısında sınır yoktur; her kampüste istediğiniz kadar okul olabilir.'));
  }

  function kampusSekmesi(c) {
    const kt = kart(ust({
      etiket: 'Kampüs', ad: c.ad, alt: [c.adres, telYaz(c.telefon)].filter(Boolean).join(' · ') || `${c.okullar.length} okul`,
      eylem: v.kurumYonetimi ? dugme('Düzenle', 'hafif kucuk', '#kampus-duzenle/' + c.id) : null,
    }));
    for (const o of c.okullar) {
      const mudur = o.yoneticiler.find(y => y.gorev === 'mudur');
      kt.append(satir({
        avatar: logo(o.ad, logoUrl(o)), ad: o.ad, href: '#okul/' + o.id,
        alt: [[o.tur, `${o.sinif} sınıf`, `${o.ogrenci} öğrenci`].filter(Boolean).join(' · '), el('small', mudur ? `Müdür: ${mudur.ad}` : 'Müdür atanmadı', mudur ? 'kd-mudur' : 'kd-yok')],
      }));
    }
    if (!c.okullar.length) kt.append(bosNot('Bu kampüse henüz okul eklenmedi.'));
    if (v.kurumYonetimi) { const e = satir({ ad: '+ Okul ekle', href: '#okul-yeni/' + c.id }); e.classList.add('kd-ekle'); kt.append(e); }
    kok.append(kt);
  }

  function okulSayfasi(o) {
    kok.append(geri(v.kampusler.find(c => c.id === o.kampusId)?.ad || 'Okul kurulumu', '#kampus/' + o.kampusId));
    const kt = kart(
      ust({ avatar: logo(o.ad, logoUrl(o)), ad: o.ad, alt: o.tur, eylem: v.kurumYonetimi ? dugme('Düzenle', 'hafif kucuk', '#okul-duzenle/' + o.id) : null }),
      bilgi(okulBilgisi(o), o.adres),
    );
    const tn = tanitim(o);
    if (tn) kt.append(tn);
    kt.append(altBaslik('Okul yönetimi'));
    const mudur = o.yoneticiler.filter(y => y.gorev === 'mudur'), yrd = o.yoneticiler.filter(y => y.gorev === 'mudur_yrd');
    if (!o.yoneticiler.length) kt.append(bosNot('Henüz müdür ya da müdür yardımcısı atanmadı.'));
    else if (!mudur.length) kt.append(bosNot('Müdür atanmadı.'));
    for (const y of [...mudur, ...yrd]) {
      let sag = null;
      if (v.kurumYonetimi) {
        sag = el('button', 'Kaldır', 'kd-tehlike kucuk'); sag.type = 'button';
        sag.addEventListener('click', async () => {
          if (!confirm(`${y.ad}, ${o.ad} ${v.gorevler[y.gorev].toLowerCase()} görevinden kaldırılsın mı?`)) return;
          await yap('/api/yonetim/yonetici-kaldir', { id: y.id }, 'Görevden kaldırıldı.');
        });
      }
      kt.append(satir({ avatar: avatarYap(y.ad, y.foto, 'kucuk'), ad: y.ad, alt: [v.gorevler[y.gorev], telYaz(y.telefon)].filter(Boolean).join(' · '), sag }));
    }
    if (v.kurumYonetimi) { const e = satir({ ad: '+ Yönetici ekle', href: '#yonetici/' + o.id }); e.classList.add('kd-ekle'); kt.append(e); }
    kt.append(eylem(dugme('Sayılar ve yazdır', 'hafif', '/kampusler#okul/' + o.id)));
    kok.append(kt);
  }

  function kurumFormu() {
    const k = v.kurum, url = v.logo ? `/api/kurum-logo?v=${v.logo}` : null;
    const f = el('form', undefined, 'kd-form');
    const ad = girdi(k.ad, { required: true, maxLength: 80 });
    const kisa = girdi(k.kisaAd, { maxLength: 30, placeholder: 'İsteğe bağlı' });
    const tel = girdi(telYaz(k.telefon), { type: 'tel', maxLength: 30 });
    const ep = girdi(k.eposta, { type: 'email', maxLength: 80 });
    const adr = girdi(k.adres);
    const lg = logoSecici(k.ad, url);
    const tn = tanitimAlanlari(k, 'kp');
    const bilgiler = [alan('Kurum adı', ad, 'kp-ad'), satirlar(alan('Kısa ad', kisa, 'kp-kisa'), alan('Telefon', tel, 'kp-tel')),
      alan('E-posta', ep, 'kp-ep'), alan('Adres', adr, 'kp-adr'), alan('Logo', lg.kap, 'kp-logo')];
    if (v.logo) bilgiler.push(tehlike('Mevcut logoyu kaldır', async () => {
      if (!confirm('Kurum logosu kaldırılsın mı?')) return;
      await yap('/api/yonetim/kurum-logo-sil', {}, 'Logo kaldırıldı.', () => '#kurum-duzenle');
    }));
    const kb = el('div', undefined, 'kd-kurucu');
    kb.append(el('p', 'Kurucu yalnızca kayıttır; giriş ya da yetki vermez.', 'kd-bos'));
    for (const c of v.kurucular) {
      const sag = el('button', 'Kaldır', 'kd-tehlike kucuk'); sag.type = 'button';
      sag.addEventListener('click', async () => {
        if (!confirm(`${c.ad} kurucu kaydından çıkarılsın mı?`)) return;
        acilacakSekme = 'Kurucu';
        await yap('/api/yonetim/kurucu-kaldir', { userId: c.userId }, 'Kurucu kaydı kaldırıldı.', () => '#kurum-duzenle');
      });
      kb.append(satir({ avatar: avatarYap(c.ad, c.foto, 'kucuk'), ad: c.ad, alt: 'Kurucu', sag }));
    }
    if (!v.kurucular.length) kb.append(bosNot('Kurucu kaydedilmedi.'));
    const ke = satir({ ad: '+ Kurucu ekle', href: '#kurucu' }); ke.classList.add('kd-ekle'); kb.append(ke);
    sekmeliForm(f, [['Bilgiler', bilgiler], ['Tanıtım', tn.dugumler], ['Kurucu', [kb]]]);
    f.append(cubuk('#'));
    f.addEventListener('submit', async e => {
      e.preventDefault();
      const r = await api('/api/yonetim/kurum-kaydet', { ad: ad.value, kisaAd: kisa.value, telefon: tel.value, eposta: ep.value, adres: adr.value, ...tn.oku() });
      if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
      let ek = '';
      if (lg.blob) { const h = await logoYukle('/api/yonetim/kurum-logo', lg.blob); if (h) ek = ' ' + h; }
      await yukle(false);
      mesaj('Kurum profili kaydedildi.' + ek, ek ? 'hata' : 'tamam');
      git('#');
    });
    formSayfasi('Okul kurulumu', '#', 'Kurum profili', f);
  }

  function kampusFormu(kampus) {
    const f = el('form', undefined, 'kd-form');
    const ad = girdi(kampus?.ad, { required: true, maxLength: 80 });
    const adr = girdi(kampus?.adres);
    const tel = girdi(telYaz(kampus?.telefon), { type: 'tel', maxLength: 30 });
    f.append(alan('Kampüs adı', ad, 'kf-ad'), alan('Adres', adr, 'kf-adr'), alan('Telefon', tel, 'kf-tel'));
    if (kampus) f.append(tehlike('Kampüsü sil', async () => {
      if (!confirm(`${kampus.ad} kampüsü silinsin mi?`)) return;
      await yap('/api/yonetim/kampus-sil', { id: kampus.id }, 'Kampüs silindi.', () => '#');
    }));
    const kampusGeri = kampus ? '#kampus/' + kampus.id : '#';
    f.append(cubuk(kampusGeri));
    f.addEventListener('submit', async e => {
      e.preventDefault();
      const r = await api('/api/yonetim/kampus-kaydet', { id: kampus?.id ?? null, ad: ad.value, adres: adr.value, telefon: tel.value });
      if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
      await yukle(false);
      mesaj('Kampüs kaydedildi.', 'tamam');
      git('#kampus/' + r.veri.id);
    });
    formSayfasi(kampus ? kampus.ad : 'Okul kurulumu', kampusGeri, kampus ? 'Kampüsü düzenle' : 'Yeni kampüs', f);
  }

  function okulFormu(okul, kampusId) {
    const f = el('form', undefined, 'kd-form');
    const ad = girdi(okul?.ad, { required: true, maxLength: 80, placeholder: 'Okul adı' });
    const tur = secenek(el('select'), [['', 'Seçilmedi'], ...v.turler.map(t => [t, t])]); tur.value = okul?.tur || '';
    const kod = girdi(okul?.kurumKodu, { maxLength: 30 });
    const tel = girdi(telYaz(okul?.telefon), { type: 'tel', maxLength: 30 });
    const ep = girdi(okul?.eposta, { type: 'email', maxLength: 80 });
    const adr = girdi(okul?.adres);
    const lg = logoSecici(okul?.ad, okul ? logoUrl(okul) : null);
    const tn = tanitimAlanlari(okul, 'of');
    const bilgiler = [alan('Okul adı', ad, 'of-ad'), satirlar(alan('Okul türü', tur, 'of-tur'), alan('Kurum kodu', kod, 'of-kod')),
      satirlar(alan('Telefon', tel, 'of-tel'), alan('E-posta', ep, 'of-ep')), alan('Adres', adr, 'of-adr'), alan('Logo', lg.kap, 'of-logo')];
    if (okul?.logo) bilgiler.push(tehlike('Mevcut logoyu kaldır', async () => {
      if (!confirm('Okul logosu kaldırılsın mı?')) return;
      await yap('/api/okul-logo-sil?id=' + okul.id, {}, 'Logo kaldırıldı.', () => '#okul-duzenle/' + okul.id);
    }));
    if (okul) bilgiler.push(tehlike('Okulu sil', async () => {
      if (!confirm(`${okul.ad} silinsin mi? Okulda sınıf ya da kayıtlı kişi varsa silinemez.`)) return;
      await yap('/api/yonetim/okul-sil', { id: okul.id }, 'Okul silindi.', () => '#kampus/' + kampusId);
    }));
    sekmeliForm(f, [['Bilgiler', bilgiler], ['Tanıtım', tn.dugumler]]);
    const geriHedef = okul ? '#okul/' + okul.id : '#kampus/' + kampusId;
    f.append(cubuk(geriHedef));
    f.addEventListener('submit', async e => {
      e.preventDefault();
      const r = await api('/api/yonetim/okul-kaydet', { id: okul?.id ?? null, kampusId, ad: ad.value, tur: tur.value, kurumKodu: kod.value, telefon: tel.value, eposta: ep.value, adres: adr.value, ...tn.oku() });
      if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
      let ek = '';
      if (lg.blob) { const h = await logoYukle('/api/okul-logo?id=' + r.veri.id, lg.blob); if (h) ek = ' ' + h; }
      await yukle(false);
      mesaj('Okul kaydedildi.' + ek, ek ? 'hata' : 'tamam');
      git('#okul/' + r.veri.id);
    });
    const kampus = v.kampusler.find(c => c.id === kampusId);
    formSayfasi(okul ? okul.ad : 'Okul kurulumu', geriHedef, okul ? 'Okulu düzenle' : 'Yeni okul', f, kampus?.ad);
  }

  function yoneticiFormu(okul) {
    const f = el('form', undefined, 'kd-form');
    const mudurVar = okul.yoneticiler.some(y => y.gorev === 'mudur');
    const gorev = secenek(el('select'), Object.entries(v.gorevler));
    gorev.value = mudurVar ? 'mudur_yrd' : 'mudur';
    const mevcut = new Set(okul.yoneticiler.map(y => y.userId));
    const kisi = secenek(el('select'), [['yeni', 'Yeni kişi ekle…'], ...v.adaylar.filter(a => !mevcut.has(a.userId)).map(a => [String(a.userId), `${a.ad} · ${a.rol}${a.okul ? ' · ' + a.okul : ''}`])]);
    const yeni = el('div', undefined, 'ku-yeni');
    const ad = girdi('', { maxLength: 80, placeholder: 'Ad soyad' });
    const kimlik = girdi('', { maxLength: 20, placeholder: 'T.C. kimlik / pasaport no' });
    const tel = girdi('', { type: 'tel', maxLength: 30, placeholder: '5XX XXX XX XX' });
    yeni.append(alan('Ad soyad', ad, 'yf-ad'), satirlar(alan('Kimlik / pasaport no', kimlik, 'yf-kimlik'), alan('Telefon', tel, 'yf-tel')));
    kisi.addEventListener('change', () => yeni.classList.toggle('gizli', kisi.value !== 'yeni'));
    f.append(alan('Görev', gorev, 'yf-gorev'), alan('Kişi', kisi, 'yf-kisi'), yeni, cubuk('#okul/' + okul.id));
    f.addEventListener('submit', async e => {
      e.preventDefault();
      const govde = { okulId: okul.id, gorev: gorev.value };
      if (kisi.value === 'yeni') Object.assign(govde, { ad: ad.value, kimlik: kimlik.value, telefon: tel.value });
      else govde.userId = Number(kisi.value);
      const r = await api('/api/yonetim/yonetici-ekle', govde);
      if (!r.ok) return mesaj(r.veri.hata || 'Eklenemedi', 'hata');
      await yukle(false);
      mesaj('Yönetici eklendi.', 'tamam');
      git('#okul/' + okul.id);
    });
    formSayfasi(okul.ad, '#okul/' + okul.id, 'Yönetici ekle', f, 'Müdür ya da müdür yardımcısı');
  }

  function kurucuFormu() {
    acilacakSekme = 'Kurucu';
    const f = el('form', undefined, 'kd-form');
    const mevcut = new Set(v.kurucular.map(c => c.userId));
    const kisi = secenek(el('select'), [['yeni', 'Yeni kişi ekle…'], ...v.adaylar.filter(a => !mevcut.has(a.userId)).map(a => [String(a.userId), `${a.ad} · ${a.rol}${a.okul ? ' · ' + a.okul : ''}`])]);
    const yeni = el('div', undefined, 'ku-yeni');
    const ad = girdi('', { maxLength: 80, placeholder: 'Ad soyad' });
    const kimlik = girdi('', { maxLength: 20, placeholder: 'T.C. kimlik / pasaport no' });
    const tel = girdi('', { type: 'tel', maxLength: 30, placeholder: '5XX XXX XX XX' });
    yeni.append(alan('Ad soyad', ad, 'kc-ad'), satirlar(alan('Kimlik / pasaport no', kimlik, 'kc-kimlik'), alan('Telefon', tel, 'kc-tel')));
    kisi.addEventListener('change', () => yeni.classList.toggle('gizli', kisi.value !== 'yeni'));
    f.append(alan('Kişi', kisi, 'kc-kisi'), yeni, cubuk('#kurum-duzenle'));
    f.addEventListener('submit', async e => {
      e.preventDefault();
      const govde = kisi.value === 'yeni' ? { ad: ad.value, kimlik: kimlik.value, telefon: tel.value } : { userId: Number(kisi.value) };
      const r = await api('/api/yonetim/kurucu-ekle', govde);
      if (!r.ok) return mesaj(r.veri.hata || 'Eklenemedi', 'hata');
      await yukle(false);
      mesaj('Kurucu kaydedildi.', 'tamam');
      git('#kurum-duzenle');
    });
    formSayfasi('Kurumu düzenle', '#kurum-duzenle', 'Kurucu ekle', f, 'Kurucu yalnızca kayıttır; giriş ya da yetki vermez');
  }

  function ciz() {
    if (!v) return;
    kok.replaceChildren();
    const { g, id } = rota();
    const okul = v.kampusler.flatMap(c => c.okullar).find(o => o.id === id);
    const kampus = v.kampusler.find(c => c.id === id);
    const yonetim = v.kurumYonetimi;
    if (g !== 'kurucu' && g !== 'kurum-duzenle') acilacakSekme = null;
    if (g === 'okul' && okul) okulSayfasi(okul);
    else if (yonetim && g === 'kurum-duzenle') kurumFormu();
    else if (yonetim && g === 'kampus-yeni') kampusFormu(null);
    else if (yonetim && g === 'kampus-duzenle' && kampus) kampusFormu(kampus);
    else if (yonetim && g === 'okul-yeni' && kampus) okulFormu(null, kampus.id);
    else if (yonetim && g === 'okul-duzenle' && okul) okulFormu(okul, okul.kampusId);
    else if (yonetim && g === 'yonetici' && okul) yoneticiFormu(okul);
    else if (yonetim && g === 'kurucu') kurucuFormu();
    else liste();
    window.scrollTo(0, 0);
  }

  async function yukle(ciz1 = true) {
    const r = await api('/api/yonetim/kurum');
    v = r.veri;
    if (ciz1) ciz();
  }
  window.addEventListener('hashchange', () => { if (mesajTut) mesajTut = false; else mesaj(''); ciz(); });
  yukle();
})();
