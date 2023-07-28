import isZoomed from "discourse/plugins/chat/discourse/lib/zoom-check";
import { capabilities } from "discourse/services/capabilities";
import { next, schedule } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";

// since -webkit-overflow-scrolling: touch can't be used anymore to disable momentum scrolling
// we use different hacks to work around this
// if you change any line in this method, make sure to test on iOS
export function stackingContextFix(scrollable, callback) {
  if (capabilities.isIOS) {
    scrollable.style.overflow = "hidden";
    scrollable
      .querySelectorAll(".chat-message-separator__text-container")
      .forEach((container) => (container.style.zIndex = "1"));
  }

  callback?.();

  if (capabilities.isIOS) {
    next(() => {
      schedule("afterRender", () => {
        scrollable.style.overflow = "auto";
        discourseLater(() => {
          if (!scrollable) {
            return;
          }

          scrollable
            .querySelectorAll(".chat-message-separator__text-container")
            .forEach((container) => (container.style.zIndex = "2"));
        }, 50);
      });
    });
  }
}

export function bodyScrollFix() {
  // when keyboard is visible this will ensure body
  // doesn’t scroll out of viewport
  if (
    capabilities.isIOS &&
    document.documentElement.classList.contains("keyboard-visible") &&
    !isZoomed()
  ) {
    document.documentElement.scrollTo(0, 0);
  }
}
