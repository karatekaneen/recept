// Portionsväljare: räknar om ingrediensmängderna när antalet ändras.
// Mängder med data-value skalas; text som "en näve" eller "2-3" lämnas orörd.
window.addEventListener("DOMContentLoaded", () => {
  const box = document.querySelector(".scaler");
  if (!box) return;
  const base = Number(box.dataset.base);
  if (!(base > 0)) return;
  const lang = box.dataset.lang || document.documentElement.lang;
  const input = box.querySelector("input");
  const reset = box.querySelector(".scale-reset");
  const note = document.querySelector(".scale-note");
  const qtys = document.querySelectorAll(".ingredients .qty[data-value]");

  // Stegstorlek efter receptets storlek: 1 för små satser, större steg för stora.
  const step = base <= 12 ? 1 : [1, 2, 5, 10, 20, 50].find((s) => s >= base / 10) || 50;

  const round = (v) => {
    if (v >= 100) return Math.round(v);
    if (v >= 10) return Math.round(v * 2) / 2;
    if (v >= 1) return Math.round(v * 10) / 10;
    if (v >= 0.1) return Math.round(v * 20) / 20;
    return Number(v.toPrecision(2));
  };
  const fmt = (v) => round(v).toLocaleString(lang, { maximumFractionDigits: 2 });

  const apply = (n) => {
    if (!(n > 0)) return;
    const f = n / base;
    qtys.forEach((el) => {
      const v = Number(el.dataset.value) * f;
      el.textContent = [fmt(v), el.dataset.unit].filter(Boolean).join(" ");
    });
    const changed = n !== base;
    reset.hidden = !changed;
    if (note) note.hidden = !changed;
  };

  input.addEventListener("input", () => apply(Number(input.value)));
  box.querySelectorAll(".scale-btn").forEach((b) =>
    b.addEventListener("click", () => {
      const cur = Number(input.value) || base;
      const dir = Number(b.dataset.dir);
      // Hoppa till närmaste jämna steg, och aldrig under 1.
      let next = dir > 0 ? Math.floor(cur / step) * step + step : Math.ceil(cur / step) * step - step;
      if (next < 1) next = cur > 1 ? 1 : cur;
      input.value = next;
      apply(next);
    })
  );
  reset.addEventListener("click", () => {
    input.value = base;
    apply(base);
  });
});
