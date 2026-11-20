// Sağlık kartı: okul sağlık yetkilisi, öğretmen (yalnızca uyarılar), veli (düzenler) ve öğrenci (salt okunur)
let baglam = null;
const alanlar = [
  ['alerji', 'Alerji (ilaç, besin, böcek...)'], ['kronik', 'Kronik hastalık'], ['ilac', 'Düzenli kullandığı ilaç'],
  ['ozelGereksinim', 'Özel gereksinim'], ['diyet', 'Özel beslenme'], ['gecmis', 'Geçmiş hastalık / ameliyat'],
  ['hekim', 'Aile hekimi / doktor'], ['hastane', 'Tercih edilen hastane'], ['acilNot', 'Acil durumda okulun bilmesi gerekenler'],
];

async function basla() {
  const r = await api('/api/saglik/baglam');
  if (!r.ok) return mesaj(r.veri.hata || 'Sayfa açılamadı', 'hata');
  baglam = r.veri;
  const id = sorguAl('ogrenci');
  if (id) return detayAc(id);
  if (baglam.rol === 'yonetim') return yonetimAc();
  if (baglam.rol === 'ogretmen') return listeAc('Uyarı gerektiren öğrencilerim');
  return ogrenciSec();
}

// ---------- Veli / öğrenci ----------
function ogrenciSec() {
  const l = baglam.ogrenciler || [];
  if (!l.length) { $('icerik').replaceChildren(bos('Bağlı öğrenci bulunamadı.')); return; }
  if (l.length === 1) return detayAc(l[0].id, true);
  const kap = $('icerik'); kap.replaceChildren();
  for (const o of l) {
    const b = el('button', `${o.ad}${o.sinif ? ' · ' + o.sinif : ''}`, 'ikincil'); b.type = 'button';
    b.addEventListener('click', () => detayAc(o.id, true));
    kap.append(b, ' ');
  }
}

// ---------- Okul sağlık yetkilisi ----------
function yonetimAc() {
  const kap = $('sekmeler');
  sekmeKur(kap, [['liste', 'Öğrenciler'], ['revir', 'Revir kayıtları']], ad => ad === 'liste' ? listeAc() : revirAc());
}

async function listeAc(baslik) {
  const yonetim = baglam.rol === 'yonetim';
  const icerik = $('icerik'); icerik.replaceChildren();
  if (baslik) { $('baslik').textContent = 'Sağlık uyarıları'; icerik.append(el('h2', baslik, 'baslik2')); }
  const arac = el('div', undefined, 'okul-arac');
  const okul = secim([['', 'Tüm okullar'], ...(baglam.okullar || []).map(b => [b.id, b.ad])]);
  const sinif = secim([['', 'Tüm sınıflar']]);
  const ara = girdi('search', '', { placeholder: 'Öğrenci ara', maxLength: 60 });
  const filtre = secim([['tum', 'Tümü'], ['uyari', 'Uyarısı olanlar'], ['eksik', 'Kartı doldurulmamış'], ['veli', 'Veli güncellemesi']]);
  if (yonetim) {
    if ((baglam.okullar || []).length > 1) arac.append(alan('Okul', okul));
    arac.append(alan('Sınıf', sinif), alan('Ara', ara), alan('Göster', filtre));
    icerik.append(arac);
  }
  const sonuc = el('div'); icerik.append(sonuc);
  const siniflariKur = () => {
    const o = Number(okul.value) || 0; const eski = sinif.value;
    sinif.replaceChildren(Object.assign(el('option', 'Tüm sınıflar'), { value: '' }));
    for (const c of baglam.siniflar || []) if (!o || c.okulId === o) sinif.append(Object.assign(el('option', c.ad), { value: String(c.id) }));
    sinif.value = [...sinif.options].some(x => x.value === eski) ? eski : '';
  };
  let sayac = 0;
  const yukle = async () => {
    const bu = ++sayac;
    const q = new URLSearchParams({ okul: okul.value, sinif: sinif.value, ara: ara.value, filtre: filtre.value });
    const r = await api('/api/saglik/liste?' + q);
    if (bu !== sayac) return;
    if (!r.ok) return mesaj(r.veri.hata || 'Liste alınamadı', 'hata');
    mesaj('');
    sonuc.replaceChildren();
    const t = r.veri.toplam;
    if (yonetim) {
      const k = el('div', undefined, 'sayi-kutulari');
      for (const [s, a] of [[t.ogrenci, 'Öğrenci'], [t.uyarili, 'Uyarısı olan'], [t.kartsiz, 'Kartı boş']]) { const d = el('div'); d.append(el('strong', s), a); k.append(d); }
      sonuc.append(k);
    }
    if (!r.veri.ogrenciler.length) return void sonuc.append(bos(yonetim ? 'Bu süzgece uyan öğrenci yok.' : 'Öğrencilerinizde bildirilmiş bir sağlık uyarısı yok.'));
    const sar = el('div', undefined, 'tablo-sar'); const tb = el('table');
    const bas = el('tr'); for (const h of ['Öğrenci', 'Sınıf', 'Kan', 'Uyarılar', yonetim ? 'Revir' : '']) bas.append(el('th', h));
    tb.append(bas);
    for (const s of r.veri.ogrenciler) {
      const tr = el('tr', undefined, 'tikla');
      tr.append(el('td', s.ad), el('td', s.sinif), el('td', s.kanGrubu || '-'));
      const u = el('td');
      if (s.uyarilar.length) for (const x of s.uyarilar) u.append(el('span', x, 'uyari-rozet'));
      else u.textContent = s.kartVar ? '-' : 'Kart boş';
      tr.append(u);
      tr.append(el('td', yonetim ? (s.olaySayisi ? `${s.olaySayisi} (${tarihYaz(s.sonOlay)})` : '-') : ''));
      tr.addEventListener('click', () => detayAc(s.id));
      tb.append(tr);
    }
    sar.append(tb); sonuc.append(sar);
  };
  okul.addEventListener('change', () => { siniflariKur(); yukle(); });
  sinif.addEventListener('change', yukle); filtre.addEventListener('change', yukle);
  let zaman; ara.addEventListener('input', () => { clearTimeout(zaman); zaman = setTimeout(yukle, 300); });
  siniflariKur(); yukle();
}

async function revirAc() {
  const icerik = $('icerik'); icerik.replaceChildren();
  const gun = secim([[7, 'Son 7 gün'], [30, 'Son 30 gün'], [90, 'Son 90 gün'], [365, 'Son 1 yıl']], 30);
  const arac = el('div', undefined, 'okul-arac'); arac.append(alan('Dönem', gun)); icerik.append(arac);
  const sonuc = el('div'); icerik.append(sonuc);
  const yukle = async () => {
    const r = await api('/api/saglik/olaylar?gun=' + gun.value);
    if (!r.ok) return mesaj(r.veri.hata || 'Kayıtlar alınamadı', 'hata');
    sonuc.replaceChildren();
    if (!r.veri.olaylar.length) return void sonuc.append(bos('Bu dönemde revir kaydı yok.'));
    for (const e of r.veri.olaylar) {
      const k = el('div', undefined, 'kayit-kart tikla');
      k.append(el('h3', `${e.ogrenci}${e.sinif ? ' · ' + e.sinif : ''}`));
      k.append(el('p', `${tarihYaz(e.tarih)} ${e.saat} · ${e.sonucAd}${e.veliHaber ? ' · veli bilgilendirildi' : ''}`, 'kucuk'));
      k.append(el('p', e.sikayet));
      if (e.mudahale) k.append(el('p', 'Müdahale: ' + e.mudahale));
      k.addEventListener('click', () => detayAc(e.ogrenciId));
      sonuc.append(k);
    }
  };
  gun.addEventListener('change', yukle); yukle();
}

// ---------- Öğrenci kartı ----------
async function detayAc(id, tekOgrenci) {
  const r = await api('/api/saglik/ogrenci?id=' + encodeURIComponent(id));
  if (!r.ok) return mesaj(r.veri.hata || 'Kart açılamadı', 'hata');
  mesaj('');
  const d = r.veri;
  $('sekmeler').classList.add('gizli');
  const icerik = $('icerik'); icerik.replaceChildren();
  if (!tekOgrenci) {
    const geri = el('button', '← Listeye dön', 'ikincil kucuk'); geri.type = 'button';
    geri.addEventListener('click', () => { history.replaceState(null, '', location.pathname); basla(); });
    icerik.append(geri);
  }
  icerik.append(el('h2', `${d.ogrenci.ad}${d.ogrenci.sinif ? ' · ' + d.ogrenci.sinif : ''}`, 'baslik2'));
  if (d.ogrenci.okul) icerik.append(el('p', d.ogrenci.okul, 'kucuk'));
  if (d.gorunum === 'uyari') icerik.append(el('p', 'Öğretmen görünümü: yalnızca sınıfta bilinmesi gereken uyarılar gösterilir.', 'bos-not'));
  if (d.gorunum === 'veli') icerik.append(el('p', 'Bilgileri güncel tutmanız, acil durumda okulun doğru hareket etmesini sağlar. Bu bilgiler yalnızca okul sağlık yetkilisi ve sınıf öğretmenlerinin uyarı alanları ile paylaşılır.', 'bos-not'));

  icerik.append(kartBolumu(d));
  if (d.olcumler) icerik.append(olcumBolumu(d));
  if (d.olaylar) icerik.append(olayBolumu(d));
}

function kartBolumu(d) {
  const kutu = el('div', undefined, 'bolum-kutu');
  kutu.append(el('h3', 'Sağlık bilgileri', 'baslik2'));
  const k = d.kart;
  if (!d.duzenle) {
    const gorunecek = [['kanGrubu', 'Kan grubu'], ...alanlar.filter(([a]) => a in k)];
    let var1 = false;
    for (const [a, ad] of gorunecek) {
      if (!k[a]) continue; var1 = true;
      const p = el('p'); p.append(Object.assign(el('strong', ad + ': '), {}), k[a]); kutu.append(p);
    }
    if (k.gozluk) { var1 = true; kutu.append(el('p', 'Gözlük kullanıyor')); }
    if (!var1) kutu.append(bos('Bildirilmiş bir sağlık bilgisi yok.'));
    return kutu;
  }
  const f = el('form');
  const kan = secim([['', 'Belirtilmedi'], ...baglam.kanGruplari.map(x => [x, x])], k.kanGrubu);
  const gozluk = girdi('checkbox'); gozluk.checked = !!k.gozluk;
  const satir = el('div', undefined, 'form-satir');
  satir.append(alan('Kan grubu', kan));
  const gk = el('div'); const gl = el('label', 'Gözlük kullanıyor'); gl.style.display = 'flex'; gl.style.gap = '8px'; gl.style.alignItems = 'center'; gl.prepend(gozluk); gozluk.style.width = 'auto'; gk.append(gl);
  satir.append(gk);
  f.append(satir);
  const girdiler = {};
  for (const [a, ad] of alanlar) {
    girdiler[a] = a === 'hekim' || a === 'hastane' ? girdi('text', k[a], { maxLength: 120 }) : metinAlan(k[a], a === 'gecmis' || a === 'acilNot' ? 600 : 400);
    f.append(alan(ad, girdiler[a]));
  }
  const b = el('button', 'Kaydet', 'birincil'); b.type = 'submit';
  f.append(b);
  if (k.guncelleme) f.append(el('p', `Son güncelleme: ${new Date(k.guncelleme).toLocaleDateString('tr-TR')}${k.kaynak === 'veli' ? ' (veli)' : k.kaynak ? ' (okul)' : ''}`, 'kucuk'));
  f.addEventListener('submit', async e => {
    e.preventDefault();
    const g = { ogrenciId: d.ogrenci.id, kanGrubu: kan.value, gozluk: gozluk.checked };
    for (const [a] of alanlar) g[a] = girdiler[a].value;
    const r = await api('/api/saglik/kart', g);
    mesaj(r.ok ? 'Sağlık bilgileri kaydedildi.' : (r.veri.hata || 'Kaydedilemedi'), r.ok ? 'tamam' : 'hata');
  });
  kutu.append(f);
  return kutu;
}

function olcumBolumu(d) {
  const kutu = el('div', undefined, 'bolum-kutu');
  kutu.append(el('h3', 'Boy ve kilo', 'baslik2'));
  if (d.olcumDuzenle) {
    const f = el('form'); const s = el('div', undefined, 'form-satir');
    const tarih = girdi('date', bugunTarih(), { max: bugunTarih() });
    const boy = girdi('number', '', { min: 40, max: 230, step: '0.1', placeholder: 'cm' });
    const kilo = girdi('number', '', { min: 2, max: 250, step: '0.1', placeholder: 'kg' });
    const b = el('button', 'Ölçüm ekle', 'birincil'); b.type = 'submit';
    s.append(alan('Tarih', tarih), alan('Boy (cm)', boy), alan('Kilo (kg)', kilo), b);
    f.append(s);
    f.addEventListener('submit', async e => {
      e.preventDefault();
      const r = await api('/api/saglik/olcum', { ogrenciId: d.ogrenci.id, tarih: tarih.value, boy: boy.value, kilo: kilo.value });
      if (!r.ok) return mesaj(r.veri.hata || 'Eklenemedi', 'hata');
      detayAc(d.ogrenci.id, !d.olcumDuzenle);
    });
    kutu.append(f);
  }
  if (!d.olcumler.length) { kutu.append(bos('Ölçüm kaydı yok.')); return kutu; }
  const sar = el('div', undefined, 'tablo-sar'); const tb = el('table');
  const bas = el('tr'); for (const h of ['Tarih', 'Boy', 'Kilo', 'VKİ', '']) bas.append(el('th', h)); tb.append(bas);
  for (const x of d.olcumler) {
    const tr = el('tr');
    tr.append(el('td', tarihYaz(x.tarih)), el('td', x.boy ? x.boy + ' cm' : '-'), el('td', x.kilo ? x.kilo + ' kg' : '-'), el('td', x.bki ?? '-'));
    const son = el('td');
    if (d.olcumDuzenle) {
      const sil = el('button', 'Sil', 'ikincil kucuk tehlike'); sil.type = 'button';
      sil.addEventListener('click', async () => {
        if (!onayla('Bu ölçüm silinsin mi?')) return;
        const r = await api('/api/saglik/olcum-sil', { id: x.id });
        if (!r.ok) return mesaj(r.veri.hata || 'Silinemedi', 'hata');
        detayAc(d.ogrenci.id);
      });
      son.append(sil);
    }
    tr.append(son); tb.append(tr);
  }
  sar.append(tb); kutu.append(sar);
  return kutu;
}

function olayBolumu(d) {
  const kutu = el('div', undefined, 'bolum-kutu');
  kutu.append(el('h3', 'Revir kayıtları', 'baslik2'));
  const yonetim = d.gorunum === 'yonetim';
  if (yonetim) {
    const f = el('form');
    const s = el('div', undefined, 'form-satir');
    const tarih = girdi('date', bugunTarih(), { max: bugunTarih() });
    const saat = girdi('time', '');
    const sonuc = secim(Object.entries(baglam.sonuclar), 'sinifa');
    s.append(alan('Tarih', tarih), alan('Saat', saat), alan('Sonuç', sonuc));
    const sikayet = metinAlan('', 400); const mudahale = metinAlan('', 400);
    const haber = girdi('checkbox'); haber.style.width = 'auto';
    const hl = el('label', 'Veli bilgilendirildi'); hl.style.display = 'flex'; hl.style.gap = '8px'; hl.style.alignItems = 'center'; hl.prepend(haber);
    const b = el('button', 'Revir kaydı ekle', 'birincil'); b.type = 'submit';
    f.append(s, alan('Şikâyet', sikayet), alan('Yapılan müdahale', mudahale), hl, b);
    f.addEventListener('submit', async e => {
      e.preventDefault();
      const r = await api('/api/saglik/olay', { ogrenciId: d.ogrenci.id, tarih: tarih.value, saat: saat.value, sonuc: sonuc.value, sikayet: sikayet.value, mudahale: mudahale.value, veliHaber: haber.checked });
      if (!r.ok) return mesaj(r.veri.hata || 'Kaydedilemedi', 'hata');
      detayAc(d.ogrenci.id);
    });
    kutu.append(f);
  }
  if (!d.olaylar.length) { kutu.append(bos('Revir kaydı yok.')); return kutu; }
  for (const e of d.olaylar) {
    const k = el('div', undefined, 'kayit-kart');
    k.append(el('h3', `${tarihYaz(e.tarih)} ${e.saat}`));
    k.append(el('p', e.sikayet));
    if (e.mudahale) k.append(el('p', 'Müdahale: ' + e.mudahale));
    k.append(el('p', `${e.sonucAd}${e.veliHaber ? ' · veli bilgilendirildi' : ''}${e.yazan ? ' · ' + e.yazan : ''}`, 'kucuk'));
    if (yonetim) {
      const sil = el('button', 'Sil', 'ikincil kucuk tehlike'); sil.type = 'button';
      sil.addEventListener('click', async () => {
        if (!onayla('Bu revir kaydı silinsin mi?')) return;
        const r = await api('/api/saglik/olay-sil', { id: e.id });
        if (!r.ok) return mesaj(r.veri.hata || 'Silinemedi', 'hata');
        detayAc(d.ogrenci.id);
      });
      k.append(sil);
    }
    kutu.append(k);
  }
  return kutu;
}

basla();
