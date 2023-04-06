import { schedule } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import { getOwner } from "discourse-common/lib/get-owner";

// A more consistent way to scroll to the bottom when we are sure this is our goal
// it will also limit issues with any element changing the height while we are scrolling
// to the bottom
export function scrollToBottom(scrollable) {
  scrollable.scrollTop = -1;
  forceRendering(scrollable, () => {
    scrollable.scrollTop = 0;
  });
}

// since -webkit-overflow-scrolling: touch can't be used anymore to disable momentum scrolling
// we now use this hack to disable it
export function forceRendering(scrollable, callback) {
  schedule("afterRender", () => {
    if (!scrollable) {
      return;
    }

    const capabilities = getOwner(callback).lookup("service:capabilities");

    if (capabilities.isIOS) {
      scrollable.style.overflow = "hidden";
    }

    callback?.();

    if (capabilities.isIOS) {
      discourseLater(() => {
        if (!scrollable) {
          return;
        }

        scrollable.style.overflow = "auto";
      }, 50);
    }
  });
}
