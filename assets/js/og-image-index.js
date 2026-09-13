const input = document.querySelector("#search");
const entries = [...document.querySelectorAll("[data-review-entry]")];
const sections = [...document.querySelectorAll("[data-gallery-section]")];
const visibleCount = document.querySelector("#visible-count");

input.addEventListener("input", () => {
  const query = input.value.trim().toLowerCase();
  document.body.classList.toggle("is-filtering", Boolean(query));

  let visible = 0;
  for (const entry of entries) {
    const matches = !query || entry.dataset.search.includes(query);
    entry.hidden = !matches;
    if (matches) visible += 1;
  }

  for (const section of sections) {
    const hasMatch = [...section.querySelectorAll("[data-review-entry]")].some(
      (entry) => !entry.hidden,
    );
    section.querySelector(".empty").classList.toggle("visible", !hasMatch);
  }

  visibleCount.textContent = visible.toLocaleString();
});
