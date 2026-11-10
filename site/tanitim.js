// Tanıtım sitesi: açılışta belirme, üst çubuk gölgesi, satın alma talebi formu
document.documentElement.classList.add('js');

const ust = document.getElementById('ust');
const kaydir = () => ust.classList.toggle('kay', window.scrollY > 8);
kaydir();
window.addEventListener('scroll', kaydir, { passive: true });

const ogeler = document.querySelectorAll('.rv');
if ('IntersectionObserver' in window) {
  const gozcu = new IntersectionObserver(kayitlar => {
    for (const k of kayitlar) if (k.isIntersecting) { k.target.classList.add('in'); gozcu.unobserve(k.target); }
  }, { threshold: 0.12 });
  ogeler.forEach(o => gozcu.observe(o));
} else {
  ogeler.forEach(o => o.classList.add('in'));
}

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
