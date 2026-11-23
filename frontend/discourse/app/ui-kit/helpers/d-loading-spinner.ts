import { trustHTML } from "@ember/template";

/**
 * Builds the markup of a loading spinner.
 *
 * @param cssClass - An extra class for the spinner, such as its size.
 * @returns The spinner markup.
 */
export function renderSpinner(cssClass?: string): string {
  let html = "<div class='spinner";
  if (cssClass) {
    html += " " + cssClass;
  }
  return html + "'></div>";
}

/** The markup of a loading spinner with no extra class. */
export const spinnerHTML = renderSpinner();

/**
 * Renders a loading spinner.
 *
 * @param options - The named arguments.
 * @returns The trusted spinner markup.
 */
export default function dLoadingSpinner({
  size,
}: {
  /** An extra class for the spinner, such as `"small"`. */
  size?: string;
} = {}) {
  return trustHTML(renderSpinner(size));
}
