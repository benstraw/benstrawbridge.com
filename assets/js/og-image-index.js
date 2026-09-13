const input = document.querySelector("#search");
const cards = [...document.querySelectorAll("[data-review-card]")];
const sections = [...document.querySelectorAll("[data-gallery-section]")];
const visibleCount = document.querySelector("#visible-count");

input.addEventListener("input", () => {
  const query = input.value.trim().toLowerCase();
  document.body.classList.toggle("is-filtering", Boolean(query));

  let visible = 0;
  for (const card of cards) {
    const matches = !query || card.dataset.search.includes(query);
    card.hidden = !matches;
    if (matches) visible += 1;
  }

  for (const section of sections) {
    const hasMatch = [...section.querySelectorAll("[data-review-card]")].some(
      (card) => !card.hidden,
    );
    section.querySelector(".empty").classList.toggle("visible", !hasMatch);
  }

  visibleCount.textContent = visible.toLocaleString();
});
