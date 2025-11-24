import { waitForPromise } from "@ember/test-waiters";
import { prefersReducedMotion } from "discourse/lib/utilities";

export async function waitForAnimationEnd(element) {
  return new Promise((resolve) => {
    const style = window.getComputedStyle(element);
    const duration = parseFloat(style.animationDuration) * 1000 || 0;
    const delay = parseFloat(style.animationDelay) * 1000 || 0;
    const totalTime = duration + delay;

    const handleAnimationEnd = () => {
      clearTimeout(timeoutId);
      element.removeEventListener("animationend", handleAnimationEnd);
      resolve();
    };

    const timeoutId = setTimeout(
      () => {
        element.removeEventListener("animationend", handleAnimationEnd);
        resolve();
      },
      // The timeout acts as a fallback in case the "animationend" event does not fire (e.g., when no animation is present).
      Math.max(totalTime + 50, 50)
    );

    element.addEventListener("animationend", handleAnimationEnd);
  });
}

export async function animateClosing(element, className = "-closing") {
  if (!element || prefersReducedMotion()) {
    return;
  }
  element.classList.add(className);

  await waitForPromise(waitForAnimationEnd(element));

  element.classList.remove(className);
}

export async function animateOpening(element, className = "-opening") {
  if (!element || prefersReducedMotion()) {
    return;
  }
  element.classList.add(className);

  await waitForPromise(waitForAnimationEnd(element));

  element.classList.remove(className);
}
