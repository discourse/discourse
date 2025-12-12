import { modifier as modifierFn } from "ember-modifier";
import { isAppleMobile } from "./browser-detection";

/**
 * Scroll trap modifier for d-sheet.
 * Creates a scroll trap by centering at (300, 300) in a 600x600px scrollable area
 * created by CSS ::before pseudo-element. This traps scroll gestures to prevent
 * them from propagating to the page.
 *
 * @param {HTMLElement} element - The element to attach the scroll trap to
 * @param {boolean[]} args - [active] Whether the scroll trap is active
 * @returns {Function|undefined} Cleanup function or undefined if not active
 */
export const scrollTrapModifier = modifierFn((element, [active]) => {
  if (!active) {
    return;
  }

  element.scrollTo(300, 300);

  const handleScroll = (e) => {
    const target = e.currentTarget;
    target.scrollTo(300, 300);

    if (isAppleMobile() && !CSS.supports("overscroll-behavior: contain")) {
      target.style.setProperty("overflow", "hidden");
      setTimeout(() => {
        target.style.setProperty("overflow", "auto");
      }, 10);
    }
  };
  element.addEventListener("scroll", handleScroll);

  const resizeObserver = new ResizeObserver(() => {
    element.scrollTo(300, 300);
  });
  resizeObserver.observe(element, { box: "border-box" });

  return () => {
    element.removeEventListener("scroll", handleScroll);
    resizeObserver.disconnect();
  };
});
