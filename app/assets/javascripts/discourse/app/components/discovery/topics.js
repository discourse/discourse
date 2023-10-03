import { inject as service } from "@ember/service";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import { userPath } from "discourse/lib/url";
import { action } from "@ember/object";
import Component from "@glimmer/component";
import DismissNew from "discourse/components/modal/dismiss-new";
import { filterTypeForMode } from "discourse/lib/filter-mode";

export default class DiscoveryTopics extends Component {
  @service router;
  @service composer;
  @service modal;
  @service currentUser;
  @service topicTrackingState;
  @service site;

  get redirectedReason() {
    return this.currentUser?.user_option.redirected_to_top?.reason;
  }

  get order() {
    return this.args.model.get("params.order");
  }

  get ascending() {
    return this.args.model.get("params.ascending");
  }

  get hasTopics() {
    return this.args.model.get("topics.length") > 0;
  }

  get allLoaded() {
    return !this.args.model.get("more_topics_url");
  }

  get latest() {
    return filterTypeForMode(this.args.model.filter) === "latest";
  }

  get top() {
    return filterTypeForMode(this.args.model.filter) === "top";
  }

  get new() {
    return filterTypeForMode(this.args.model.filter) === "new";
  }

  callResetNew(dismissPosts = false, dismissTopics = false, untrack = false) {
    const tracked =
      (this.router.currentRoute.queryParams["f"] ||
        this.router.currentRoute.queryParams["filter"]) === "tracked";

    let topicIds = this.args.bulkSelectHelper.selected.map((topic) => topic.id);
    Topic.resetNew(this.args.category, !this.args.noSubcategories, {
      tracked,
      tag: this.args.tag,
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

  @action
  resetNew() {
    if (!this.currentUser.new_new_view_enabled) {
      return this.callResetNew();
    }

    this.modal.show(DismissNew, {
      model: {
        selectedTopics: this.args.bulkSelectHelper.selected,
        subset: this.args.model.listParams?.subset,
        dismissCallback: ({ dismissPosts, dismissTopics, untrack }) => {
          this.callResetNew(dismissPosts, dismissTopics, untrack);
        },
      },
    });
  }

  // Show newly inserted topics
  @action
  showInserted(event) {
    event?.preventDefault();
    const tracker = this.topicTrackingState;

    // Move inserted into topics
    this.args.model.loadBefore(tracker.get("newIncoming"), true);
    tracker.resetTracking();
  }

  get showTopicsAndRepliesToggle() {
    return this.new && this.currentUser?.new_new_view_enabled;
  }

  get newRepliesCount() {
    this.topicTrackingState.get("messageCount"); // Autotrack this

    if (this.currentUser?.new_new_view_enabled) {
      return this.topicTrackingState.countUnread({
        categoryId: this.args.category?.id,
        noSubcategories: this.args.noSubcategories,
        tagId: this.args.tag?.id,
      });
    } else {
      return 0;
    }
  }

  get newTopicsCount() {
    this.topicTrackingState.get("messageCount"); // Autotrack this

    if (this.currentUser?.new_new_view_enabled) {
      return this.topicTrackingState.countNew({
        categoryId: this.args.category?.id,
        noSubcategories: this.args.noSubcategories,
        tagId: this.args.tag?.id,
      });
    } else {
      return 0;
    }
  }

  get showTopicPostBadges() {
    return !this.new || this.currentUser?.new_new_view_enabled;
  }

  get footerMessage() {
    const allLoaded = this.allLoaded;
    const topicsLength = this.args.model.get("topics.length");
    if (!allLoaded) {
      return;
    }

    const { category, tag } = this.args;
    if (category) {
      return I18n.t("topics.bottom.category", {
        category: category.get("name"),
      });
    } else if (tag) {
      return I18n.t("topics.bottom.tag", {
        tag: tag.id,
      });
    } else {
      const split = (this.args.model.get("filter") || "").split("/");
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

  get footerEducation() {
    const topicsLength = this.args.model.get("topics.length");

    if (!this.allLoaded || topicsLength > 0 || !this.currentUser) {
      return;
    }

    const segments = (this.args.model.get("filter") || "").split("/");

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
      this.showTopicsAndRepliesToggle &&
      !this.args.bulkSelectEnabled
    );
  }

  @action
  dismissRead(dismissTopics) {
    const operationType = dismissTopics ? "topics" : "posts";
    this.args.bulkSelectHelper.dismissRead(operationType, {
      categoryId: this.args.category?.id,
      tagName: this.args.tag?.id,
      includeSubcategories: this.args.noSubcategories,
    });
  }
}
