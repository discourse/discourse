import { next } from "@ember/runloop";
import { capabilities } from "discourse/services/capabilities";
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
  }
}
