// Kampüs ve okullar / Okul kurulumu sayfalarının ortak yapı taşları (düz kartlar, çizgili satırlar).
window.KD = (() => {
  const el = (tag, metin, sinif) => {
    const e = document.createElement(tag);
    if (metin !== undefined && metin !== null) e.textContent = metin;
    if (sinif) e.className = sinif;
    return e;
  };
  const telYaz = t => t && /^\d{10}$/.test(t) ? `0${t.slice(0, 3)} ${t.slice(3, 6)} ${t.slice(6, 8)} ${t.slice(8)}` : (t || '');
  const logoUrl = o => o.logo ? `/api/okul-logo?id=${o.id}&v=${o.logo}` : null;

  // Yönlendirme: #gorunum/id
  const rota = () => { const [g, id] = location.hash.slice(1).split('/'); return { g: g || '', id: Number(id) || null }; };
  const git = h => { if (location.hash === h || (h === '#' && !location.hash)) window.dispatchEvent(new HashChangeEvent('hashchange')); else location.hash = h; };

  const kart = (...cocuklar) => { const k = el('section', undefined, 'kd-kart'); k.append(...cocuklar); return k; };
  const baslik = (metin, ...eylemler) => { const b = el('div', undefined, 'kd-baslik'); b.append(el('h2', metin), ...eylemler); return b; };
  const geri = (metin, hedef) => { const a = el('a', '‹  ' + metin, 'kd-geri'); a.href = hedef; return a; };

  function yazi(etiket, ad, alt) {
    const y = el('div', undefined, 'kd-yazi');
    if (etiket) y.append(el('small', etiket, 'kd-etiket'));
    y.append(el('strong', ad));
    for (const a of [].concat(alt || [])) if (a) y.append(typeof a === 'string' ? el('small', a) : a);
    return y;
  }
  // Kart başlığı: logo/avatar + yazı + (isteğe bağlı) sağda eylem
  function ust({ avatar, etiket, ad, alt, eylem, href }) {
    const k = el(href ? 'a' : 'div', undefined, 'kd-ust');
    if (href) k.href = href;
    if (avatar) k.append(avatar);
    k.append(yazi(etiket, ad, alt));
    if (href) k.append(el('span', '›', 'kd-ok'));
    if (eylem) k.append(eylem);
    return k;
  }
  // Çizgiyle ayrılan satır: tıklanabilir (href / tik) ya da düz
  function satir({ avatar, ad, alt, href, tik, sag }) {
    const k = el(href ? 'a' : tik ? 'button' : 'div', undefined, 'kd-satir');
    if (href) k.href = href;
    if (tik) { k.type = 'button'; k.addEventListener('click', tik); }
    if (avatar) k.append(avatar);
    k.append(yazi(null, ad, alt));
    if (sag) k.append(sag);
    else if (href || tik) k.append(el('span', '›', 'kd-ok'));
    return k;
  }
  const altBaslik = metin => el('div', metin, 'kd-alt-baslik');
  function dugme(metin, tur, fn) {
    const b = el(typeof fn === 'string' ? 'a' : 'button', metin, 'kd-dugme' + (tur ? ' ' + tur : ''));
    if (typeof fn === 'string') b.href = fn; else { b.type = 'button'; b.addEventListener('click', fn); }
    return b;
  }
  const eylem = (...d) => { const e = el('div', undefined, 'kd-eylem'); e.append(...d); return e; };
  const bosNot = metin => el('p', metin, 'kd-bos');

  const topla = (okullar, alan) => okullar.reduce((n, o) => n + (o[alan] || 0), 0);
  function sayilar(okullar, kampusSayisi) {
    const t = a => topla(okullar, a);
    const yoklama = t('yoklamaToplam'), gelmedi = t('gelmedi');
    const oran = yoklama ? `%${(gelmedi * 100 / yoklama).toFixed(1).replace('.', ',')}` : '';
    const kutu = el('div', undefined, 'kd-sayilar');
    const kalemler = [
      ...(kampusSayisi ? [['Kampüs', kampusSayisi]] : []),
      ...(okullar.length !== 1 ? [['Okul', okullar.length]] : []),
      ['Sınıf', t('sinif')], ['Öğrenci', t('ogrenci')], ['Öğretmen', t('ogretmen')], ['Veli', t('veli')],
      ['Yeni kayıt', t('yeniKayit')], ['Tekrar kayıt', t('yenileme')], ['Nakil', t('nakil')],
      ...(t('kayitsiz') ? [['Kayıt türü girilmemiş', t('kayitsiz')]] : []),
      ['Devamsızlık', yoklama ? gelmedi : '—', yoklama ? `${oran} · ${t('gec')} geç · ${t('izinli')} izinli` : 'Henüz yoklama yok'],
    ];
    for (const [ad, deger, alt] of kalemler) {
      const k = el('div', undefined, 'kd-sayi' + (ad === 'Devamsızlık' ? ' genis' : ''));
      k.append(el('b', String(deger)), el('span', ad));
      if (alt) k.append(el('small', alt));
      kutu.append(k);
    }
    return kutu;
  }
  function harita(adres) {
    const a = el('a', 'Haritada aç', 'kd-harita');
    a.href = 'https://www.google.com/maps/search/?api=1&query=' + encodeURIComponent(adres);
    a.target = '_blank'; a.rel = 'noopener';
    return a;
  }
  const SOSYAL_AD = { instagram: 'Instagram', facebook: 'Facebook', x: 'X', youtube: 'YouTube', tiktok: 'TikTok', linkedin: 'LinkedIn' };
  const webHref = w => /^https?:\/\//i.test(w) ? w : 'https://' + w;
  // Tanıtım yazısı ve sosyal medya bağlantıları; ikisi de boşsa null döner
  function tanitim(n) {
    const kap = el('div', undefined, 'kd-tanitim');
    if (n.aciklama) kap.append(el('p', n.aciklama, 'kd-hakkinda'));
    const hesaplar = Object.entries(n.sosyal || {}).filter(([k, u]) => SOSYAL_AD[k] && /^https?:\/\//i.test(u));
    if (hesaplar.length) {
      const s = el('div', undefined, 'kd-sosyal');
      for (const [k, u] of hesaplar) { const a = el('a', SOSYAL_AD[k]); a.href = u; a.target = '_blank'; a.rel = 'noopener'; s.append(a); }
      kap.append(s);
    }
    return kap.childNodes.length ? kap : null;
  }
  function bilgi(satirlar, adres) {
    const b = el('div', undefined, 'kd-bilgi');
    for (const [ad, deger] of satirlar) {
      if (!deger) continue;
      const r = el('div'); r.append(el('span', ad));
      const d = el('b', ad === 'Web' ? undefined : deger);
      if (ad === 'Web') { const a = el('a', deger.replace(/^https?:\/\//i, '').replace(/\/$/, ''), 'kd-baglanti'); a.href = webHref(deger); a.target = '_blank'; a.rel = 'noopener'; d.append(a); }
      if (ad === 'Adres' && adres) d.append(document.createElement('br'), harita(adres));
      r.append(d); b.append(r);
    }
    return b;
  }
  const okulBilgisi = o => [['Okul türü', o.tur], ['Kurum kodu', o.kurumKodu], ['Telefon', telYaz(o.telefon)], ['E-posta', o.eposta], ['Web', o.web], ['Adres', o.adres]];
  const kampusBilgisi = k => [['Telefon', telYaz(k.telefon)], ['Adres', k.adres]];

  // Okulun zümreleri: branş, öğretmen sayısı ve zümre başkanı
  function zumreTablosu(o) {
    if (!o.zumreler?.length) return el('p', 'Henüz zümre yok.', 'kd-yok');
    const t = document.createElement('table'); t.className = 'kd-zumre';
    const bas = t.createTHead().insertRow();
    for (const h of ['Zümre (branş)', 'Öğretmen', 'Zümre başkanı']) bas.append(el('th', h));
    const g = t.createTBody();
    for (const z of o.zumreler) {
      const r = g.insertRow();
      r.append(el('td', z.brans), el('td', String(z.ogretmen)), el('td', z.baskan || '—'));
    }
    return t;
  }

  // Okulun zümre başkanları ve ek görevlileri (rehber, teknik ekip, güvenlik)
  function gorevliTablosu(o) {
    if (!o.gorevliler?.length) return el('p', 'Henüz görevli atanmadı.', 'kd-yok');
    const t = document.createElement('table'); t.className = 'kd-zumre kd-gorevli';
    const bas = t.createTHead().insertRow();
    for (const h of ['Ad soyad', 'Telefon']) bas.append(el('th', h));
    const g = t.createTBody();
    for (const x of o.gorevliler) {
      const r = g.insertRow();
      const kisi = el('td'); kisi.append(el('span', x.ad, 'kd-ad'), el('small', x.gorev, 'kd-gorev'));
      r.append(kisi, el('td', telYaz(x.telefon) || '—'));
    }
    return t;
  }

  function yoneticiOzeti(okullar, gorevler) {
    const b = el('div', undefined, 'kd-bilgi');
    for (const o of okullar) {
      const liste = [...o.yoneticiler.filter(y => y.gorev === 'mudur'), ...o.yoneticiler.filter(y => y.gorev === 'mudur_yrd')];
      if (!liste.length) { const r = el('div'); r.append(el('span', o.ad), el('b', 'Müdür atanmadı', 'kd-yok')); b.append(r); continue; }
      for (const y of liste) {
        const r = el('div'); r.append(el('span', `${o.ad} · ${gorevler[y.gorev]}`), el('b', [y.ad, telYaz(y.telefon)].filter(Boolean).join(' · '))); b.append(r);
      }
    }
    return b;
  }
  const bolum = dugum => { const s = el('div', undefined, 'kd-bolum'); s.append(dugum); return s; };

  // Yazdır: ayrıntıyı gizli bir kâğıda kopyalar, yalnızca onu yazdırır
  // kurum: ad ya da { ad, logo }. Logo varsa adın yanında basılır, yoksa yalnızca ad görünür (boş kutu bırakılmaz)
  function yazdir(kurum, baslikMetni, alt, ...parcalar) {
    document.getElementById('yazdir-alani')?.remove();
    const alan = el('div'); alan.id = 'yazdir-alani';
    const { ad: kurumAdi, logo } = typeof kurum === 'string' ? { ad: kurum } : kurum;
    const u = el('div', undefined, 'yz-ust');
    const marka = el('span', undefined, 'yz-marka');
    if (logo) {
      const g = el('img', undefined, 'yz-logo'); g.alt = ''; g.src = logo;
      g.onerror = () => g.remove();
      marka.append(g);
    }
    marka.append(el('span', kurumAdi));
    u.append(marka, el('span', new Date().toLocaleDateString('tr-TR')));
    alan.append(u, el('h1', baslikMetni));
    if (alt) alan.append(el('p', alt, 'yz-alt'));
    for (const [etiket, dugum] of parcalar) { alan.append(el('h2', etiket)); alan.append(dugum); }
    document.body.append(alan);
    document.body.classList.add('yazdir-ku');
    const bitir = () => { document.body.classList.remove('yazdir-ku'); alan.remove(); window.removeEventListener('afterprint', bitir); };
    window.addEventListener('afterprint', bitir);
    window.print();
  }

  return { el, telYaz, logoUrl, rota, git, kart, baslik, geri, ust, satir, altBaslik, dugme, eylem, bosNot,
    sayilar, bilgi, tanitim, SOSYAL_AD, okulBilgisi, kampusBilgisi, yoneticiOzeti, bolum, yazdir, zumreTablosu, gorevliTablosu };
})();
