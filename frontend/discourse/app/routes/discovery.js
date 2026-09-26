import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { resetCachedTopicList } from "discourse/lib/cached-topic-list";
import DiscourseRoute from "discourse/routes/discourse";
import CurrentUserService from "discourse/services/current-user";
import SessionService from "discourse/services/session";
import SiteService from "discourse/services/site";

/**
  The parent route for all discovery routes.
**/
export default class DiscoveryRoute extends DiscourseRoute {
  @service(() => CurrentUserService) currentUser;
  @service router;
  @service(() => SessionService) session;
  @service(() => SiteService) site;

  queryParams = {
    filter: { refreshModel: true },
  };

  beforeModel(transition) {
    const url = transition.intent.url;
    let matches;
    if (
      (url === "/" || url === "/latest" || url === "/categories") &&
      !transition.targetName.includes("discovery.top") &&
      this.currentUser?.get("user_option.should_be_redirected_to_top")
    ) {
      this.currentUser?.get("user_option.should_be_redirected_to_top", false);
      const period =
        this.currentUser?.get("user_option.redirected_to_top.period") || "all";
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
