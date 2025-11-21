export function waitForAnimationEnd(element) {
  return new Promise((resolve) => {
    const style = window.getComputedStyle(element);
    const duration = parseFloat(style.animationDuration) * 1000 || 0;
    const delay = parseFloat(style.animationDelay) * 1000 || 0;
    const totalTime = duration + delay;

    const timeoutId = setTimeout(
      () => {
        element.removeEventListener("animationend", handleAnimationEnd);
        resolve();
      },
      Math.max(totalTime + 50, 50)
    );

    const handleAnimationEnd = () => {
      clearTimeout(timeoutId);
      element.removeEventListener("animationend", handleAnimationEnd);
      resolve();
    };

    element.addEventListener("animationend", handleAnimationEnd);
  });
}
