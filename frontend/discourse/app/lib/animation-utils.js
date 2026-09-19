import { waitForPromise } from "@ember/test-waiters";
import { isTesting } from "discourse/lib/environment";
import { prefersReducedMotion } from "discourse/lib/utilities";

export function waitForAnimationEnd(element) {
  return waitForPromise(
    new Promise((resolve) => {
      const style = window.getComputedStyle(element);
      const duration = parseFloat(style.animationDuration) * 1000 || 0;
      const delay = parseFloat(style.animationDelay) * 1000 || 0;

      const handleAnimationEnd = () => {
        clearTimeout(timeoutId);
        element.removeEventListener("animationend", handleAnimationEnd);
        resolve();
      };

      // Fallback in case the `animationend` event does not fire (e.g., when no animation is present).
      const timeoutId = setTimeout(
        () => {
          element.removeEventListener("animationend", handleAnimationEnd);
          resolve();
        },
        Math.max(duration + delay + 50, 50)
      );

      element.addEventListener("animationend", handleAnimationEnd);
    })
  );
}

export async function animateClosing(element, className = "-closing") {
  if (!element || prefersReducedMotion() || isTesting()) {
    return;
  }
  element.classList.add(className);

  await waitForAnimationEnd(element);

  element.classList.remove(className);
}
