import { capabilities } from "discourse/services/capabilities";

// since -webkit-overflow-scrolling: touch can't be used anymore to disable momentum scrolling
// we use different hacks to work around this
// if you change any line in this method, make sure to test on iOS
export function stackingContextFix(scrollable, callback) {
  callback?.();

  if (capabilities.isIOS) {
    // stores scroll position otherwise we will lose it
    const currentScroll = scrollable.scrollTop;

    const display = scrollable.style.display;
    scrollable.style.display = "none"; // forces redraw on the container
    scrollable.offsetHeight; // triggers a reflow
    scrollable.style.display = display;

    scrollable.scrollTop = currentScroll;
  }
}
