// Tanıtım sayfası: satın alma talebi formu
const form = document.getElementById('talep');
const mesaj = document.getElementById('t-mesaj');

form.addEventListener('submit', async e => {
  e.preventDefault();
  mesaj.className = 'mesaj';
  mesaj.textContent = '';
  const veri = Object.fromEntries(new FormData(form));
  const dugme = form.querySelector('button[type=submit]');
  dugme.disabled = true;
  try {
    const r = await fetch('https://app.neademy.com/api/satin-alma', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(veri),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.hata || 'Talep gönderilemedi, lütfen tekrar deneyin');
    form.reset();
    mesaj.className = 'mesaj ok';
    mesaj.textContent = 'Talebiniz alındı. Sizi en kısa sürede arayacağız.';
  } catch (err) {
    mesaj.className = 'mesaj hata';
    mesaj.textContent = err instanceof TypeError ? 'Şu an bağlanılamadı. Lütfen biraz sonra tekrar deneyin.' : err.message;
  } finally {
    dugme.disabled = false;
  }
});
