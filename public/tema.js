// Açık (beyaz) tema tek temadır. Koyu tema kaldırıldı; eskiden saklanmış tercih de temizlenir.
document.documentElement.classList.remove('koyu');
try { localStorage.removeItem('tema'); } catch {}
