import { htmlSafe } from "@ember/template";

export function renderSpinner(cssClass) {
  let html = "<div class='spinner";
  if (cssClass) {
    html += " " + cssClass;
  }
  return html + "'></div>";
}

export const spinnerHTML = renderSpinner();

export default function loadingSpinner({ size } = {}) {
  return htmlSafe(renderSpinner(size));
}
