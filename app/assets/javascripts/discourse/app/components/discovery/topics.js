import { alias, empty, equal, gt, not, readOnly } from "@ember/object/computed";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import DismissTopics from "discourse/mixins/dismiss-topics";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import deprecated from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";
import { endWith } from "discourse/lib/computed";
import { routeAction } from "discourse/helpers/route-action";
import { inject as service } from "@ember/service";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { action } from "@ember/object";
import Component from "@ember/component";

export default Component.extend(BulkTopicSelection, DismissTopics, {
  // discovery: controller(),
  router: service(),

  period: null,
  canCreateTopicOnCategory: null,

  canStar: alias("currentUser.id"),
  showTopicPostBadges: not("new"),
  redirectedReason: alias("currentUser.user_option.redirected_to_top.reason"),

  expandGloballyPinned: false,
  expandAllPinned: false,

  order: readOnly("model.params.order"),
  ascending: readOnly("model.params.ascending"),

  selected: null,

  // Remove these actions which are defined in `DiscoveryController`
  // We want them to bubble in DiscoveryTopicsController
  @action
  loadingBegan() {
    this.set("application.showFooter", false);
    return true;
  },

  @action
  loadingComplete() {
    this.set("application.showFooter", this.loadedAllItems);
    return true;
  },

  @discourseComputed("model.filter", "model.topics.length")
  showDismissRead(filter, topicsLength) {
    return this._isFilterPage(filter, "unread") && topicsLength > 0;
  },

  @discourseComputed("model.filter", "model.topics.length")
  showResetNew(filter, topicsLength) {
    return this._isFilterPage(filter, "new") && topicsLength > 0;
  },

  callResetNew(dismissPosts = false, dismissTopics = false, untrack = false) {
    const tracked =
      (this.router.currentRoute.queryParams["f"] ||
        this.router.currentRoute.queryParams["filter"]) === "tracked";

    let topicIds = this.selected
      ? this.selected.map((topic) => topic.id)
      : null;

    Topic.resetNew(this.category, !this.noSubcategories, {
      tracked,
      topicIds,
      dismissPosts,
      dismissTopics,
      untrack,
    }).then((result) => {
      if (result.topic_ids) {
        this.topicTrackingState.removeTopics(result.topic_ids);
      }
      this.send(
        "refresh",
        tracked ? { skipResettingParams: ["filter", "f"] } : {}
      );
    });
  },

  // Show newly inserted topics
  @action
  showInserted(event) {
    event?.preventDefault();
    const tracker = this.topicTrackingState;

    // Move inserted into topics
    this.model.loadBefore(tracker.get("newIncoming"), true);
    tracker.resetTracking();
  },

  actions: {
    changeSort() {
      deprecated(
        "changeSort has been changed from an (action) to a (route-action)",
        {
          since: "2.6.0",
          dropFrom: "2.7.0",
          id: "discourse.topics.change-sort",
        }
      );
      return routeAction("changeSort", this.router._router, ...arguments)();
    },
  },

  @action
  refresh() {
    this.send("triggerRefresh");
  },

  afterRefresh(filter, list, listModel = list) {
    this.setProperties({ model: listModel });
    this.resetSelected();

    if (this.topicTrackingState) {
      this.topicTrackingState.sync(list, filter);
    }

    this.send("loadingComplete");
  },

  hasTopics: gt("model.topics.length", 0),
  allLoaded: empty("model.more_topics_url"),
  latest: endWith("model.filter", "latest"),
  top: endWith("model.filter", "top"),
  yearly: equal("period", "yearly"),
  quarterly: equal("period", "quarterly"),
  monthly: equal("period", "monthly"),
  weekly: equal("period", "weekly"),
  daily: equal("period", "daily"),

  @discourseComputed("model.filter")
  new(filter) {
    return filter?.endsWith("new") && !this.currentUser?.new_new_view_enabled;
  },

  @discourseComputed("allLoaded", "model.topics.length")
  footerMessage(allLoaded, topicsLength) {
    if (!allLoaded) {
      return;
    }

    const category = this.category;
    if (category) {
      return I18n.t("topics.bottom.category", {
        category: category.get("name"),
      });
    } else {
      const split = (this.get("model.filter") || "").split("/");
      if (topicsLength === 0) {
        return I18n.t("topics.none." + split[0], {
          category: split[1],
        });
      } else {
        return I18n.t("topics.bottom." + split[0], {
          category: split[1],
        });
      }
    }
  },

  @discourseComputed("allLoaded", "model.topics.length")
  footerEducation(allLoaded, topicsLength) {
    if (!allLoaded || topicsLength > 0 || !this.currentUser) {
      return;
    }

    const segments = (this.get("model.filter") || "").split("/");

    let tab = segments[segments.length - 1];

    if (tab !== "new" && tab !== "unread") {
      return;
    }

    if (tab === "new" && this.currentUser.new_new_view_enabled) {
      tab = "new_new";
    }

    return I18n.t("topics.none.educate." + tab, {
      userPrefsUrl: userPath(
        `${this.currentUser.get("username_lower")}/preferences/tracking`
      ),
    });
  },

  @action
  changePeriod(p) {
    DiscourseURL.routeTo(this.showMoreUrl(p));
  },
});
