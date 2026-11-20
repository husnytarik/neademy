// Veli ve öğrenci için servis bilgisi
async function basla() {
  const r = await api('/api/servis/benim');
  if (!r.ok) return mesaj(r.veri.hata || 'Servis bilgisi alınamadı', 'hata');
  const icerik = $('icerik'); icerik.replaceChildren();
  if (!r.veri.ogrenciler.length) return void icerik.append(bos('Bağlı öğrenci bulunamadı.'));
  for (const o of r.veri.ogrenciler) {
    const kutu = el('div', undefined, 'bolum-kutu');
    kutu.append(el('h2', `${o.ad}${o.sinif ? ' · ' + o.sinif : ''}`, 'baslik2'));
    const s = o.servis;
    if (!s) { kutu.append(bos('Bu öğrenci için kayıtlı bir servis yok.')); icerik.append(kutu); continue; }
    const satir = (a, v) => { if (v) { const p = el('p'); p.append(el('strong', a + ': '), v); kutu.append(p); } };
    satir('Servis', s.servis + (s.aktif ? '' : ' (şu an hizmet dışı)'));
    satir('Plaka', s.plaka);
    satir('Şoför', [s.soforAd, s.soforTel].filter(Boolean).join(' · '));
    satir('Hostes', [s.hostesAd, s.hostesTel].filter(Boolean).join(' · '));
    satir('Kullanım', s.yonAd);
    if (s.durak) {
      satir('Durak', s.durak.ad);
      if (s.yon !== 'aksam') satir('Sabah saati', s.durak.sabahSaat);
      if (s.yon !== 'sabah') satir('Akşam saati', s.durak.aksamSaat);
    }
    satir('Not', s.notu);
    icerik.append(kutu);
  }
}
basla();
