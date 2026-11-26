// Rullgardinerna i menyn: bara en öppen åt gången, stängs vid klick utanför eller Esc.
const drops = [...document.querySelectorAll(".nav-drop")];

drops.forEach((d) =>
  d.addEventListener("toggle", () => {
    if (d.open) drops.forEach((o) => o !== d && (o.open = false));
  }),
);

document.addEventListener("click", (e) => {
  drops.forEach((d) => d.open && !d.contains(e.target) && (d.open = false));
});

document.addEventListener("keydown", (e) => {
  if (e.key !== "Escape") return;
  const open = drops.find((d) => d.open);
  if (open) {
    open.open = false;
    open.querySelector("summary").focus();
  }
});
