import { scheduleOnce } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";
import DiscourseURL from "discourse/lib/url";

const context = {
  _scrollTop() {
    if (isTesting()) {
      return;
    }
    document.documentElement.scrollTop = 0;
  },
};

function scrollTop() {
  if (DiscourseURL.isJumpScheduled()) {
    return;
  }
  scheduleOnce("afterRender", context, context._scrollTop);
}

export { scrollTop };
