import { scheduleOnce } from "@ember/runloop";
import DiscourseURL from "discourse/lib/url";
import { isTesting } from "discourse-common/config/environment";

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
