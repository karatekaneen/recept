// Startar Pagefinds sökruta i sidhuvudet. Pagefind väljer index efter <html lang>.
const script = document.currentScript;
window.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("sok");
  if (!el || typeof PagefindUI === "undefined") return;
  new PagefindUI({
    element: el,
    bundlePath: script?.dataset.bundle || "/pagefind/",
    showSubResults: false,
    showImages: true,
    resetStyles: false,
    translations: { placeholder: script?.dataset.placeholder },
  });
});
