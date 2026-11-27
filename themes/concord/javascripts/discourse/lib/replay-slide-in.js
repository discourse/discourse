// Core's slide-in time.
const DURATION = 200;

/**
 * Core starts the slide-in channel list's opening slide just before the
 * channels inside it render. On a phone that render holds up the frame, and
 * the slide is timed from the frame's start, so by the time the list is
 * first drawn the slide is over and the list seems to pop in. This plays the
 * slide from where the list was last drawn, starting when it's drawn with
 * its channels.
 *
 * @param {Element} element Something rendered inside the list.
 */
export default function replaySlideIn(element) {
  const panel = element.closest(".menu-panel.slide-in");
  if (!panel || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return;
  }

  // Runs before the first frame that has the channels in it, while the
  // panel's animations still read as of that frame's (stale) start.
  requestAnimationFrame(() => {
    const transform = getComputedStyle(panel).transform;
    const from = transform === "none" ? 0 : new DOMMatrix(transform).m41;
    if (!from) {
      return;
    }

    const slide = panel.animate(
      [
        { transform: `translate3d(${from}px, 0, 0)` },
        { transform: "translate3d(0, 0, 0)" },
      ],
      {
        duration: DURATION * Math.min(1, Math.abs(from) / panel.offsetWidth),
        easing: "ease-out",
        fill: "backwards",
      }
    );
    // Timed from now, not from the frame's start.
    slide.startTime = performance.now();
  });
}
