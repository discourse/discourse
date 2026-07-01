import { modifier as modifierFn } from "ember-modifier";
import { capabilities } from "discourse/services/capabilities";

const SCROLL_CENTER_POSITION = 300;
const IOS_OVERFLOW_RESTORE_DELAY_MS = 10;
function needsIOSRubberBandWorkaround() {
  return (
    capabilities.isAppleMobile && !CSS.supports("overscroll-behavior: contain")
  );
}
function scrollToCenter(element) {
  element.scrollTo(SCROLL_CENTER_POSITION, SCROLL_CENTER_POSITION);
}
function applyIOSRubberBandWorkaround(element) {
  element.style.setProperty("overflow", "hidden");
  setTimeout(() => {
    element.style.setProperty("overflow", "auto");
  }, IOS_OVERFLOW_RESTORE_DELAY_MS);
}
export const scrollTrapModifier = modifierFn((element, [active]) => {
  if (!active) {
    return;
  }

  const requiresIOSWorkaround = needsIOSRubberBandWorkaround();

  scrollToCenter(element);
  const handleScroll = (e) => {
    const target = e.currentTarget;
    scrollToCenter(target);

    if (requiresIOSWorkaround) {
      applyIOSRubberBandWorkaround(target);
    }
  };

  element.addEventListener("scroll", handleScroll);
  const resizeObserver = new ResizeObserver((entries) => {
    entries.forEach(() => {
      scrollToCenter(element);
    });
  });
  resizeObserver.observe(element, { box: "border-box" });

  return () => {
    element.removeEventListener("scroll", handleScroll);
    resizeObserver.disconnect();
  };
});
