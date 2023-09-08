import { inject as controller } from "@ember/controller";
import { inject as service } from "@ember/service";
import { alias, empty, equal, gt, readOnly } from "@ember/object/computed";
import BulkTopicSelection from "discourse/mixins/bulk-topic-selection";
import DismissTopics from "discourse/mixins/dismiss-topics";
import DiscoveryController from "discourse/controllers/discovery";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import deprecated from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";
import { endWith } from "discourse/lib/computed";
import { routeAction } from "discourse/helpers/route-action";
import { userPath } from "discourse/lib/url";
import { action } from "@ember/object";

export default class TopicsController extends DiscoveryController.extend(
  BulkTopicSelection,
  DismissTopics
) {
  @service router;
  @service composer;
  @controller discovery;

  period = null;
  selected = null;
  expandGloballyPinned = false;
  expandAllPinned = false;

  @alias("currentUser.id") canStar;
  @alias("currentUser.user_option.redirected_to_top.reason") redirectedReason;
  @readOnly("model.params.order") order;
  @readOnly("model.params.ascending") ascending;
  @gt("model.topics.length", 0) hasTopics;
  @empty("model.more_topics_url") allLoaded;
  @endWith("model.filter", "latest") latest;
  @endWith("model.filter", "top") top;
  @equal("period", "yearly") yearly;
  @equal("period", "quarterly") quarterly;
  @equal("period", "monthly") monthly;
  @equal("period", "weekly") weekly;
  @equal("period", "daily") daily;

  @discourseComputed("model.filter", "model.topics.length")
  showDismissRead(filter, topicsLength) {
    return this._isFilterPage(filter, "unread") && topicsLength > 0;
  }

  @discourseComputed("model.filter", "model.topics.length")
  showResetNew(filter, topicsLength) {
    return this._isFilterPage(filter, "new") && topicsLength > 0;
  }

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
  }

  // Show newly inserted topics
  @action
  showInserted(event) {
    event?.preventDefault();
    const tracker = this.topicTrackingState;

    // Move inserted into topics
    this.model.loadBefore(tracker.get("newIncoming"), true);
    tracker.resetTracking();
  }

  @action
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
  }

  @action
  refresh() {
    this.send("triggerRefresh");
  }

  afterRefresh(filter, list, listModel = list) {
    this.setProperties({ model: listModel });
    this.resetSelected();

    if (this.topicTrackingState) {
      this.topicTrackingState.sync(list, filter);
    }

    this.send("loadingComplete");
  }

  @discourseComputed("model.filter")
  new(filter) {
    return filter?.endsWith("new");
  }

  @discourseComputed("new")
  showTopicsAndRepliesToggle(isNew) {
    return isNew && this.currentUser?.new_new_view_enabled;
  }

  @discourseComputed("topicTrackingState.messageCount")
  newRepliesCount() {
    if (this.currentUser?.new_new_view_enabled) {
      return this.topicTrackingState.countUnread({
        categoryId: this.category?.id,
        noSubcategories: this.noSubcategories,
      });
    } else {
      return 0;
    }
  }

  @discourseComputed("topicTrackingState.messageCount")
  newTopicsCount() {
    if (this.currentUser?.new_new_view_enabled) {
      return this.topicTrackingState.countNew({
        categoryId: this.category?.id,
        noSubcategories: this.noSubcategories,
      });
    } else {
      return 0;
    }
  }

  @discourseComputed("new")
  showTopicPostBadges(isNew) {
    return !isNew || this.currentUser?.new_new_view_enabled;
  }

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
  }

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
  }

  get renderNewListHeaderControls() {
    return (
      this.site.mobileView &&
      this.get("showTopicsAndRepliesToggle") &&
      !this.get("bulkSelectEnabled")
    );
  }
}
