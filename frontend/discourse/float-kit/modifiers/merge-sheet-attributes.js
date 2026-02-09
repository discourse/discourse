import { modifier } from "ember-modifier";

export default modifier((element, positional) => {
  const extra = positional.flat().filter(Boolean).join(" ");
  if (!extra) {
    return;
  }

  const current = element.getAttribute("data-d-sheet") || "";
  element.setAttribute(
    "data-d-sheet",
    [current, extra].filter(Boolean).join(" ")
  );
});
