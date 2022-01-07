import { alias, empty, equal, gt, not, readOnly } from "@ember/object/computed";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import DiscoveryController from "discourse/controllers/discovery";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import TopicList from "discourse/models/topic-list";
import { inject as controller } from "@ember/controller";
import deprecated from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";
import { endWith } from "discourse/lib/computed";
import { routeAction } from "discourse/helpers/route-action";
import { inject as service } from "@ember/service";
import { userPath } from "discourse/lib/url";
import { action } from "@ember/object";

const controllerOpts = {
  discovery: controller(),
  discoveryTopics: controller("discovery/topics"),
  router: service(),

  period: null,
  canCreateTopicOnCategory: null,

  canStar: alias("currentUser.id"),
  showTopicPostBadges: not("discoveryTopics.new"),
  redirectedReason: alias("currentUser.redirected_to_top.reason"),

  expandGloballyPinned: false,
  expandAllPinned: false,

  order: readOnly("model.params.order"),
  ascending: readOnly("model.params.ascending"),

  selected: null,

  // Remove these actions which are defined in `DiscoveryController`
  // We want them to bubble in DiscoveryTopicsController
  @action
  loadingBegan() {
    return true;
  },

  @action
  loadingComplete() {
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

  actions: {
    changeSort() {
      deprecated(
        "changeSort has been changed from an (action) to a (route-action)",
        { since: "2.6.0", dropFrom: "2.7.0" }
      );
      return routeAction("changeSort", this.router._router, ...arguments)();
    },

    // Show newly inserted topics
    showInserted() {
      const tracker = this.topicTrackingState;

      // Move inserted into topics
      this.model.loadBefore(tracker.get("newIncoming"), true);
      tracker.resetTracking();
      return false;
    },

    refresh(options = { skipResettingParams: [] }) {
      const filter = this.get("model.filter");
      this.send("resetParams", options.skipResettingParams);

      // Don't refresh if we're still loading
      if (this.discovery.loading) {
        return;
      }

      // If we `send('loading')` here, due to returning true it bubbles up to the
      // router and ember throws an error due to missing `handlerInfos`.
      // Lesson learned: Don't call `loading` yourself.
      this.discovery.loadingBegan();

      this.topicTrackingState.resetTracking();

      this.store.findFiltered("topicList", { filter }).then((list) => {
        TopicList.hideUniformCategory(list, this.category);

        // If query params are present in the current route, we need still need to sync topic
        // tracking with the topicList without any query params. Then we set the topic
        // list to the list filtered with query params in the afterRefresh.
        const params = this.router.currentRoute.queryParams;
        if (Object.keys(params).length) {
          this.store
            .findFiltered("topicList", { filter, params })
            .then((listWithParams) => {
              this.afterRefresh(filter, list, listWithParams);
            });
        } else {
          this.afterRefresh(filter, list);
        }
      });
    },

    resetNew() {
      const tracked =
        (this.router.currentRoute.queryParams["f"] ||
          this.router.currentRoute.queryParams["filter"]) === "tracked";

      let topicIds = this.selected
        ? this.selected.map((topic) => topic.id)
        : null;

      Topic.resetNew(this.category, !this.noSubcategories, {
        tracked,
        topicIds,
      }).then(() =>
        this.send(
          "refresh",
          tracked ? { skipResettingParams: ["filter", "f"] } : {}
        )
      );
    },
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
  new: endWith("model.filter", "new"),
  top: endWith("model.filter", "top"),
  yearly: equal("period", "yearly"),
  quarterly: equal("period", "quarterly"),
  monthly: equal("period", "monthly"),
  weekly: equal("period", "weekly"),
  daily: equal("period", "daily"),

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

    const tab = segments[segments.length - 1];
    if (tab !== "new" && tab !== "unread") {
      return;
    }

    return I18n.t("topics.none.educate." + tab, {
      userPrefsUrl: userPath(
        `${this.currentUser.get("username_lower")}/preferences/notifications`
      ),
    });
  },
};

export default DiscoveryController.extend(controllerOpts, BulkTopicSelection);
