import DiscourseRoute from "discourse/routes/discourse";
import User from "discourse/models/user";
import { action } from "@ember/object";
import { resetCachedTopicList } from "discourse/lib/cached-topic-list";
import { inject as service } from "@ember/service";

/**
  The parent route for all discovery routes.
**/
export default class DiscoveryRoute extends DiscourseRoute {
  @service router;

  queryParams = {
    filter: { refreshModel: true },
  };

  redirect() {
    return this.redirectIfLoginRequired();
  }

  beforeModel(transition) {
    const url = transition.intent.url;
    let matches;
    if (
      (url === "/" || url === "/latest" || url === "/categories") &&
      !transition.targetName.includes("discovery.top") &&
      User.currentProp("user_option.should_be_redirected_to_top")
    ) {
      User.currentProp("user_option.should_be_redirected_to_top", false);
      const period =
        User.currentProp("user_option.redirected_to_top.period") || "all";
      this.router.replaceWith("discovery.top", {
        queryParams: {
          period,
        },
      });
    } else if (url && (matches = url.match(/top\/(.*)$/))) {
      if (this.site.periods.includes(matches[1])) {
        this.router.replaceWith("discovery.top", {
          queryParams: {
            period: matches[1],
          },
        });
      }
    }
  }

  // clear a pinned topic
  @action
  clearPin(topic) {
    topic.clearPin();
  }

  refresh() {
    resetCachedTopicList(this.session);
    super.refresh();
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
