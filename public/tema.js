// Koyu tema (varsayılan): tercih tarayıcıda saklanır; ilk çizimden önce uygulanır, düğme sayfa yüklenince eklenir
const koyuMu = () => { try { return localStorage.getItem('tema') !== 'acik'; } catch { return true; } };
document.documentElement.classList.toggle('koyu', koyuMu());
document.addEventListener('DOMContentLoaded', () => {
  const b = document.createElement('button');
  b.type = 'button'; b.className = 'tema-dugme';
  const ciz = () => { const k = document.documentElement.classList.contains('koyu'); b.textContent = k ? '☀' : '☾'; b.title = b.ariaLabel = k ? 'Açık temaya geç' : 'Koyu temaya geç'; };
  b.addEventListener('click', () => {
    const k = !document.documentElement.classList.contains('koyu');
    document.documentElement.classList.toggle('koyu', k);
    try { localStorage.setItem('tema', k ? 'koyu' : 'acik'); } catch {}
    ciz();
  });
  ciz();
  document.body.appendChild(b);
});
