import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

const SCROLL_END_TIMEOUT = 90;
export class TouchHandler {
  sheet = null;
  isTrackingScroll = false;
  scrollendTimeout = null;
  scrollendHandler = null;

  constructor(sheet) {
    this.sheet = sheet;
  }

  handleScrollStart() {
    if (!this.sheet.scrollContainer) {
      return;
    }
    this.sheet.onTouchGestureStart?.();
    this.isTrackingScroll = true;
  }

  handleScrollEnd() {
    if (!this.isTrackingScroll) {
      return;
    }
    this.sheet.onTouchGestureEnd?.();
    this.startScrollendMonitor();
    this.isTrackingScroll = false;
  }

  startScrollendMonitor() {
    this.stopScrollendMonitor();

    if (!this.sheet.scrollContainer) {
      return;
    }

    this.scrollendHandler = () => {
      this.handleScrollendComplete();
    };

    if ("onscrollend" in window) {
      this.sheet.scrollContainer.addEventListener(
        "scrollend",
        this.scrollendHandler
      );
    }

    this.scrollendTimeout = discourseLater(() => {
      this.isTrackingScroll = false;
      if (!("onscrollend" in window)) {
        this.scrollendHandler?.();
      }
    }, SCROLL_END_TIMEOUT);
  }

  handleScrollendComplete() {
    this.stopScrollendMonitor();
  }

  stopScrollendMonitor() {
    if (this.scrollendHandler && this.sheet.scrollContainer) {
      this.sheet.scrollContainer.removeEventListener(
        "scrollend",
        this.scrollendHandler
      );
    }
    this.scrollendHandler = null;

    if (this.scrollendTimeout) {
      cancel(this.scrollendTimeout);
      this.scrollendTimeout = null;
    }
  }

  detach() {
    this.stopScrollendMonitor();
    this.isTrackingScroll = false;
  }
}
