// Öğrenci ve veli: rehberlik servisinin gönderdiği anket ve testler
async function basla() {
  const r = await api('/api/rehberlik/benim');
  if (!r.ok) return mesaj(r.veri.hata || 'Liste alınamadı', 'hata');
  const icerik = $('icerik'); icerik.replaceChildren();
  const liste = r.veri.formlar;
  if (!liste.length) return void icerik.append(bos('Şu an cevaplayacağınız bir anket ya da test yok.'));
  const bekleyen = liste.filter(f => !f.cevaplandi), biten = liste.filter(f => f.cevaplandi);
  const bolum = (baslik, dizi, cevapli) => {
    if (!dizi.length) return;
    icerik.append(el('h2', baslik, 'baslik2'));
    for (const f of dizi) {
      const k = el('div', undefined, 'kayit-kart');
      k.append(el('h3', f.ad));
      k.append(el('p', [f.tur === 'test' ? 'Test' : 'Anket', r.veri.cocukSayisi > 1 || f.ogrenciAd ? f.ogrenciAd : '', f.sonTarih ? 'Son tarih: ' + tarihYaz(f.sonTarih) : ''].filter(Boolean).join(' · '), 'kucuk'));
      if (f.aciklama) k.append(el('p', f.aciklama));
      if (cevapli) {
        if (f.sonuc) k.append(sonucKutusu(f.sonuc));
        else k.append(el('p', 'Cevabınız alındı. Teşekkürler.', 'kucuk'));
      } else {
        const b = el('button', 'Cevapla', 'birincil'); b.type = 'button';
        b.addEventListener('click', () => formAc(f));
        k.append(b);
      }
      icerik.append(k);
    }
  };
  bolum('Cevap bekleyenler', bekleyen, false);
  bolum('Cevapladıklarım', biten, true);
}

function sonucKutusu(s) {
  const k = el('div', undefined, 'bos-not');
  k.append(el('strong', `Puanınız: ${s.puan} / ${s.enYuksek}`));
  if (s.yorum) { k.append(el('br')); k.append(el('strong', s.yorum.baslik)); if (s.yorum.aciklama) { k.append(el('br')); k.append(s.yorum.aciklama); } }
  return k;
}

async function formAc(f) {
  const r = await api(`/api/rehberlik/form-cevap?id=${f.formId}&ogrenci=${f.ogrenciId}`);
  if (!r.ok) { mesaj(r.veri.hata || 'Form açılamadı', 'hata'); return basla(); }
  mesaj('');
  const { form, sorular, ogrenci } = r.veri;
  const icerik = $('icerik'); icerik.replaceChildren();
  const geri = el('button', '← Listeye dön', 'ikincil kucuk'); geri.type = 'button'; geri.addEventListener('click', basla);
  icerik.append(geri, el('h2', form.ad, 'baslik2'));
  if (form.aciklama) icerik.append(el('p', form.aciklama));
  icerik.append(el('p', form.anonim ? 'Bu anket anonimdir; cevaplarınız adınızla birlikte gösterilmez.' : `Cevaplayan öğrenci: ${ogrenci.ad}`, 'kucuk'));
  const fm = el('form');
  const okuyucular = [];
  sorular.forEach((s, i) => {
    const kutu = el('fieldset', undefined, 'soru-kutu');
    kutu.append(el('legend', `${i + 1}. ${s.metin}`));
    if (s.tip === 'metin') {
      const t = metinAlan('', 500, 3); kutu.append(t);
      okuyucular.push(() => t.value.trim() || null);
    } else {
      const ad = 'soru' + i;
      s.secenekler.forEach((metin, j) => {
        const l = el('label', undefined, 'secenek');
        const rd = girdi('radio', String(s.tip === 'likert' ? j + 1 : j), { name: ad });
        l.append(rd, metin); kutu.append(l);
      });
      okuyucular.push(() => { const x = fm.querySelector(`input[name="${ad}"]:checked`); return x ? Number(x.value) : null; });
    }
    fm.append(kutu);
  });
  const b = el('button', 'Gönder', 'birincil'); b.type = 'submit';
  fm.append(b);
  fm.addEventListener('submit', async e => {
    e.preventDefault();
    const cevaplar = okuyucular.map(o => o());
    const bos1 = sorular.findIndex((s, i) => s.tip !== 'metin' && cevaplar[i] === null);
    if (bos1 >= 0) return mesaj(`${bos1 + 1}. soruyu yanıtlayın`, 'hata');
    b.disabled = true;
    const x = await api('/api/rehberlik/cevap', { formId: f.formId, ogrenciId: f.ogrenciId, cevaplar });
    if (!x.ok) { b.disabled = false; return mesaj(x.veri.hata || 'Gönderilemedi', 'hata'); }
    mesaj('Cevabınız kaydedildi. Teşekkürler.', 'tamam');
    icerik.replaceChildren();
    if (x.veri.sonuc) icerik.append(el('h2', 'Sonucunuz', 'baslik2'), sonucKutusu(x.veri.sonuc));
    const d = el('button', 'Listeye dön', 'birincil'); d.type = 'button'; d.addEventListener('click', basla);
    icerik.append(d);
  });
  icerik.append(fm);
}
basla();
