import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class DiscoveryTopics extends Component {
  @service router;
  @service composer;
  @service modal;
  @service currentUser;
  @service topicTrackingState;
  @service site;

  @tracked loadingNew;

  get redirectedReason() {
    return this.currentUser?.user_option.redirected_to_top?.reason;
  }

  get order() {
    return this.args.model.get("params.order");
  }

  get ascending() {
    return this.args.model.get("params.ascending") === "true";
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

  get hot() {
    return filterTypeForMode(this.args.model.filter) === "hot";
  }

  get new() {
    return filterTypeForMode(this.args.model.filter) === "new";
  }

  // Show newly inserted topics
  @action
  async showInserted(event) {
    event?.preventDefault();

    if (this.args.model.loadingBefore) {
      return; // Already loading
    }

    const { topicTrackingState } = this;

    try {
      const topicIds = [...topicTrackingState.newIncoming];
      await this.args.model.loadBefore(topicIds, true);
      topicTrackingState.clearIncoming(topicIds);
    } catch (e) {
      popupAjaxError(e);
    }
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
    const topicsLength = this.args.model.get("topics.length");
    if (!this.allLoaded) {
      return;
    }

    const { category, tag } = this.args;
    if (category) {
      return i18n("topics.bottom.category", {
        category: category.get("name"),
      });
    } else if (tag) {
      return i18n("topics.bottom.tag", {
        tag: tag.id,
      });
    } else {
      const split = (this.args.model.get("filter") || "").split("/");
      if (topicsLength === 0) {
        return i18n("topics.none." + split[0], {
          category: split[1],
        });
      } else {
        return i18n("topics.bottom." + split[0], {
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

    return i18n("topics.none.educate." + tab, {
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

  get expandGloballyPinned() {
    return !this.expandAllPinned;
  }

  get expandAllPinned() {
    return this.args.tag || this.args.category;
  }
}
