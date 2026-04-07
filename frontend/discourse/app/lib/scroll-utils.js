/**
 * Probes the actual min and max scrollLeft values for an element by
 * temporarily scrolling to extremes and reading back the clamped values.
 *
 * Needed because RTL elements can have negative scrollLeft ranges
 * (e.g. min = -200, max = 0 in Chromium) and the range varies by browser.
 *
 * Temporarily forces scroll-behavior: auto so the probe is synchronous
 * even when smooth scrolling is enabled via CSS.
 */
export function measureScrollBounds(element) {
  const savedBehavior = element.style.scrollBehavior;
  element.style.scrollBehavior = "auto";
  const saved = element.scrollLeft;
  element.scrollLeft = -1e7;
  const min = element.scrollLeft;
  element.scrollLeft = 1e7;
  const max = element.scrollLeft;
  element.scrollLeft = saved;
  element.style.scrollBehavior = savedBehavior;
  return { min, max };
}
