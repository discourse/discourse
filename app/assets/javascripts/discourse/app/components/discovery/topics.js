import { inject as service } from "@ember/service";
import { alias, empty, equal, gt, readOnly } from "@ember/object/computed";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import DismissTopics from "discourse/mixins/dismiss-topics";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import discourseComputed from "discourse-common/utils/decorators";
import { endWith } from "discourse/lib/computed";
import { userPath } from "discourse/lib/url";
import { action } from "@ember/object";
import Component from "@ember/component";

export default class DiscoveryTopics extends Component.extend(DismissTopics) {
  @service router;
  @service composer;

  bulkSelectHelper = new BulkSelectHelper(this);

  period = null;
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

  callResetNew(dismissPosts = false, dismissTopics = false, untrack = false) {
    const tracked =
      (this.router.currentRoute.queryParams["f"] ||
        this.router.currentRoute.queryParams["filter"]) === "tracked";

    let topicIds = this.bulkSelectHelper.selected.map((topic) => topic.id);
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
      this.router.refresh();
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

  @action
  dismissRead(dismissTopics) {
    const operationType = dismissTopics ? "topics" : "posts";
    this.bulkSelectHelper.dismissRead(operationType, {
      categoryId: this.category?.id,
      includeSubcategories: this.noSubcategories,
    });
  }
}
