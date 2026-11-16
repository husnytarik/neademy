// Demo hesaplarla tek tıkla giriş. Sunucu anahtarsız kipteyse doğrudan listelenir; anahtar kipinde #k=... bağlantısı kullanılır.
(() => {
  const mesaj = document.getElementById('mesaj');
  const kap = document.getElementById('gruplar');
  // Anahtar bağlantıdan bir kez alınır, bu tarayıcıda hatırlanır; giriş sayfasındaki "Hızlı giriş" bağlantısı da buna bakar
  let anahtar = decodeURIComponent((location.hash.match(/k=([^&]+)/) || [])[1] || '');
  try { if (anahtar) localStorage.setItem('hizliAnahtar', anahtar); else anahtar = localStorage.getItem('hizliAnahtar') || ''; } catch {}
  const yaz = m => { mesaj.textContent = m || ''; };
  const form = document.getElementById('anahtar-form');
  fetch('/api/hizli/liste' + (anahtar ? '?k=' + encodeURIComponent(anahtar) : ''), { cache: 'no-store' }).then(r => r.ok ? r.json() : Promise.reject()).then(v => {
    for (const g of v.gruplar) {
      if (!g.kisiler.length) continue;
      const bolum = document.createElement('section');
      const h = document.createElement('h2'); h.className = 'baslik2'; h.textContent = g.ad; bolum.appendChild(h);
      const liste = document.createElement('div'); liste.style.cssText = 'display:grid;gap:8px;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));margin-bottom:18px';
      for (const k of g.kisiler) {
        const b = document.createElement('button'); b.type = 'button'; b.className = 'ikincil';
        b.style.cssText = 'text-align:left;display:block;height:auto;padding:10px 14px;white-space:normal';
        const a = document.createElement('strong'); a.textContent = k.etiket; a.style.display = 'block';
        const s = document.createElement('span'); s.className = 'alt'; s.textContent = k.alt; s.style.cssText = 'display:block;font-size:.82em';
        b.append(a, s);
        b.addEventListener('click', async () => {
          yaz('Giriş yapılıyor…');
          try {
            const r = await fetch('/api/hizli/giris', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ k: anahtar || undefined, id: k.id }) });
            if (!r.ok) throw new Error();
            location.href = '/panel';
          } catch { yaz('Giriş yapılamadı.'); }
        });
        liste.appendChild(b);
      }
      bolum.appendChild(liste); kap.appendChild(bolum);
    }
  }).catch(() => { yaz('Liste alınamadı: hızlı giriş kapalı ya da anahtar gerekiyor.'); try { localStorage.removeItem('hizliAnahtar'); } catch {} form.classList.remove('gizli'); });
})();
