import { waitForPromise } from "@ember/test-waiters";
import { isTesting } from "discourse/lib/environment";
import { prefersReducedMotion } from "discourse/lib/utilities";

// Resolves on the animationend/transitionend event, or on a timeout if the event never triggers.
function waitForEndEvent(element, eventName, styleKey, filter) {
  return waitForPromise(
    new Promise((resolve) => {
      const style = window.getComputedStyle(element);
      const duration = parseFloat(style[`${styleKey}Duration`]) * 1000 || 0;
      const delay = parseFloat(style[`${styleKey}Delay`]) * 1000 || 0;

      const handler = (event) => {
        if (filter && !filter(event)) {
          return;
        }

        clearTimeout(timeoutId);
        element.removeEventListener(eventName, handler);
        resolve();
      };

      const timeoutId = setTimeout(
        () => {
          element.removeEventListener(eventName, handler);
          resolve();
        },
        Math.max(duration + delay + 50, 50)
      );

      element.addEventListener(eventName, handler);
    })
  );
}

export function waitForAnimationEnd(element) {
  return waitForEndEvent(element, "animationend", "animation");
}

export function waitForTransitionEnd(element, propertyName) {
  return waitForEndEvent(
    element,
    "transitionend",
    "transition",
    (event) => event.propertyName === propertyName
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
