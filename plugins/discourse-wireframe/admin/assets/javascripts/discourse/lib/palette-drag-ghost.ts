const THUMBNAIL_SELECTOR =
  ".wireframe-block-row__thumbnail, .wireframe-block-tile__thumbnail";

/**
 * Builds the image the browser carries while a palette block is dragged: a
 * tile-shaped card with the block's sketch and its name, whichever shape the
 * source has. A row's description and a tile's screen-reader text are left
 * out, so rows and Recent tiles drag the same thing and the ghost never
 * stretches to a row's width.
 *
 * @param source - The row or tile being dragged.
 * @returns A detached element for the drag preview container.
 */
export function buildPaletteDragGhost(source: HTMLElement): HTMLElement {
  const ghost = document.createElement("div");
  ghost.className = "wireframe-block-tile --ghost";

  const thumbnail = source.querySelector(THUMBNAIL_SELECTOR);
  if (thumbnail) {
    const copy = thumbnail.cloneNode(true) as HTMLElement;
    copy.classList.remove("wireframe-block-row__thumbnail");
    copy.classList.add("wireframe-block-tile__thumbnail");
    ghost.append(copy);
  }

  const label = document.createElement("span");
  label.className = "wireframe-block-tile__label";
  label.textContent = source.getAttribute("aria-label") ?? "";
  ghost.append(label);

  return ghost;
}
