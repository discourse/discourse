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
export const scrollTrapModifier = modifierFn((element, [active]) => {
  if (!active) {
    return;
  }

  const requiresIOSWorkaround = needsIOSRubberBandWorkaround();
  let overflowRestoreTimer = null;
  let originalOverflow = null;

  const applyIOSRubberBandWorkaround = () => {
    if (!originalOverflow) {
      originalOverflow = {
        priority: element.style.getPropertyPriority("overflow"),
        value: element.style.getPropertyValue("overflow"),
      };
    }

    clearTimeout(overflowRestoreTimer);
    element.style.setProperty("overflow", "hidden");
    overflowRestoreTimer = setTimeout(() => {
      overflowRestoreTimer = null;
      element.style.setProperty("overflow", "auto");
    }, IOS_OVERFLOW_RESTORE_DELAY_MS);
  };

  scrollToCenter(element);
  const handleScroll = (e) => {
    const target = e.currentTarget;
    scrollToCenter(target);

    if (requiresIOSWorkaround) {
      applyIOSRubberBandWorkaround();
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
    clearTimeout(overflowRestoreTimer);

    if (originalOverflow) {
      if (originalOverflow.value) {
        element.style.setProperty(
          "overflow",
          originalOverflow.value,
          originalOverflow.priority
        );
      } else {
        element.style.removeProperty("overflow");
      }
    }

    element.removeEventListener("scroll", handleScroll);
    resizeObserver.disconnect();
  };
});
