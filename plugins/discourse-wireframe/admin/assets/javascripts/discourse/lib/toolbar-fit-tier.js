// @ts-check

/**
 * Required slack, in pixels, between the available width and a tier's natural
 * width before we let that tier win. Absorbs sub-pixel rounding (and the small
 * error from summing several elements' `offsetWidth`s) so a badge sitting right
 * on a boundary doesn't flip back and forth.
 */
export const EPSILON = 1;

/**
 * The fit tier for a block badge, chosen purely from measured widths. Exported
 * as a pure function so the decision can be unit-tested without a DOM, and used
 * as the `decide` policy the badge hands to the shared fit coordinator.
 *
 *   - `full`     — the whole inline bar fits, so every action stays inline.
 *   - `narrow`   — the full bar doesn't fit, but the identity handle plus the
 *                  hamburger does, so the actions fold into the hamburger.
 *   - `narrower` — even handle + hamburger doesn't fit, so the handle drops its
 *                  name (to a tooltip) and only the grip + hamburger remain.
 *
 * @param {number} avail - The block's available content width (`chrome.clientWidth`).
 * @param {number} naturalFull - The bar's natural width with all actions inline.
 * @param {number} naturalCompact - The bar's natural width with the actions folded
 *   into the hamburger (handle + hamburger).
 * @returns {"full"|"narrow"|"narrower"}
 */
export function computeTier(avail, naturalFull, naturalCompact) {
  if (avail >= naturalFull + EPSILON) {
    return "full";
  }
  if (avail >= naturalCompact + EPSILON) {
    return "narrow";
  }
  return "narrower";
}
