// Kampüs ve okullar: salt okunur özet. Liste → kampüs / okul sayfası (sayılar, devamsızlık, adres, yöneticiler, yazdır).
(() => {
  const { el, telYaz, logoUrl, rota, kart, baslik, geri, ust, satir, altBaslik, dugme, eylem, bosNot,
    sayilar, bilgi, tanitim, okulBilgisi, kampusBilgisi, yoneticiOzeti, yazdir, zumreTablosu, gorevliTablosu } = KD;
  const kok = document.getElementById('kampus-bolum');
  let v = null;

  const tumOkullar = () => v.kampusler.flatMap(k => k.okullar);
  const okulBul = id => tumOkullar().find(o => o.id === id);
  const logo = (ad, url) => avatarYap(ad, url, 'orta logo');
  // Kurum föyü: her kampüsün okulları ve yöneticileri (müdür, müdür yardımcıları)
  function kampusYonetimi() {
    const kap = el('div', undefined, 'kd-kampus-yonetim');
    for (const c of v.kampusler) {
      kap.append(el('h3', `${c.ad} · ${c.okullar.length} okul`));
      kap.append(c.okullar.length ? yoneticiOzeti(c.okullar, v.gorevler) : bosNot('Bu kampüste okul yok.'));
    }
    return kap;
  }
  const kurumLogo = d => d.logo ? `/api/kurum-logo?v=${d.logo}` : null;

  function okulSatiri(o) {
    const mudur = o.yoneticiler.find(y => y.gorev === 'mudur');
    return satir({
      avatar: logo(o.ad, logoUrl(o)), ad: o.ad, href: '#okul/' + o.id,
      alt: [[o.tur, `${o.sinif} sınıf`, `${o.ogrenci} öğrenci`].filter(Boolean).join(' · '), el('small', mudur ? `Müdür: ${mudur.ad}` : 'Müdür atanmadı', mudur ? 'kd-mudur' : 'kd-yok')],
    });
  }

  function liste() {
    const k = v.kurum, okullar = tumOkullar();
    const kurucu = v.kurucular.map(c => c.ad).join(', ');
    kok.append(kart(
      ust({ avatar: logo(k.ad, kurumLogo(v)), ad: k.ad,
        alt: [`${v.kampusler.length} kampüs · ${okullar.length} okul`, kurucu && `Kurucu: ${kurucu}`] }),
      sayilar(okullar),
      ...[tanitim(k)].filter(Boolean),
      eylem(dugme('Yazdır', '', () => yazdir({ ad: k.ad, logo: kurumLogo(v) }, k.ad, 'Kurum bilgi föyü', ['Genel durum', sayilar(okullar, v.kampusler.length)], ['Kampüs ve okul yönetimi', kampusYonetimi()], ...okullar.map(o => [`Zümre başkanları ve görevliler · ${o.ad}`, gorevliTablosu(o)])))),
    ));
    if (!v.kampusler.length) { kok.append(bosNot('Henüz kampüs eklenmedi.')); return; }
    kok.append(baslik('Kampüsler'));
    for (const c of v.kampusler) {
      const kt = kart(ust({ etiket: 'Kampüs', ad: c.ad, alt: [c.adres, telYaz(c.telefon)].filter(Boolean).join(' · ') || `${c.okullar.length} okul`, href: '#kampus/' + c.id }));
      for (const o of c.okullar) kt.append(okulSatiri(o));
      if (!c.okullar.length) kt.append(bosNot('Bu kampüse henüz okul eklenmedi.'));
      kok.append(kt);
    }
  }

  function okulSayfasi(o) {
    const c = v.kampusler.find(x => x.id === o.kampusId);
    kok.append(geri('Kampüs ve okullar', c ? '#kampus/' + c.id : '#'));
    kok.append(kart(
      ust({ avatar: logo(o.ad, logoUrl(o)), etiket: c?.ad, ad: o.ad, alt: o.tur }),
      sayilar([o]),
      bilgi(okulBilgisi(o), o.adres),
      ...[tanitim(o)].filter(Boolean),
      altBaslik('Okul yönetimi'),
      yoneticiOzeti([o], v.gorevler),
      eylem(
        dugme('Yazdır', '', () => yazdir({ ad: v.kurum.ad, logo: logoUrl(o) || kurumLogo(v) }, o.ad, [o.tur, 'Okul bilgi föyü'].filter(Boolean).join(' · '),
          ['Genel durum', sayilar([o])], ['Bilgiler', bilgi(okulBilgisi(o), o.adres)], ['Okul yönetimi', yoneticiOzeti([o], v.gorevler)], ['Zümreler', zumreTablosu(o)])),
        ...(v.kurumYonetimi ? [dugme('Düzenle', 'hafif', '/kurum#okul-duzenle/' + o.id)] : []),
      ),
    ));
  }

  function kampusSayfasi(c) {
    kok.append(geri('Kampüs ve okullar', '#'));
    const kt = kart(
      ust({ etiket: 'Kampüs', ad: c.ad, alt: `${c.okullar.length} okul` }),
      sayilar(c.okullar),
      bilgi(kampusBilgisi(c), c.adres),
    );
    if (c.okullar.length) {
      kt.append(altBaslik('Okullar'));
      for (const o of c.okullar) kt.append(okulSatiri(o));
      kt.append(altBaslik('Okul yönetimi'), yoneticiOzeti(c.okullar, v.gorevler));
    }
    kt.append(eylem(
      dugme('Yazdır', '', () => yazdir({ ad: v.kurum.ad, logo: kurumLogo(v) }, c.ad, 'Kampüs bilgi föyü',
        ['Genel durum', sayilar(c.okullar)], ['Bilgiler', bilgi([...kampusBilgisi(c), ['Okullar', c.okullar.map(o => o.ad).join(', ')]], c.adres)], ['Okul yönetimi', yoneticiOzeti(c.okullar, v.gorevler)], ...c.okullar.map(o => [`Zümreler · ${o.ad}`, zumreTablosu(o)]))),
      ...(v.kurumYonetimi ? [dugme('Düzenle', 'hafif', '/kurum#kampus-duzenle/' + c.id)] : []),
    ));
    kok.append(kt);
  }

  function ciz() {
    if (!v) return;
    kok.replaceChildren();
    const { g, id } = rota();
    if (g === 'okul' && okulBul(id)) okulSayfasi(okulBul(id));
    else if (g === 'kampus' && v.kampusler.some(c => c.id === id)) kampusSayfasi(v.kampusler.find(c => c.id === id));
    else liste();
    window.scrollTo(0, 0);
  }

  window.addEventListener('hashchange', ciz);
  (async () => {
    const r = await fetch('/api/yonetim/kurum');
    if (r.status === 401) { location.href = '/'; return; }
    if (r.status === 403) { location.href = '/panel'; return; }
    v = await r.json();
    ciz();
  })();
})();
