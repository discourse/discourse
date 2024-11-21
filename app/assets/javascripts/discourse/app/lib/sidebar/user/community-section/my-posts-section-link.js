import { tracked } from "@glimmer/tracking";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

const USER_DRAFTS_CHANGED_EVENT = "user-drafts:changed";

export default class MyPostsSectionLink extends BaseSectionLink {
  @tracked draftCount = this.currentUser?.draft_count;

  constructor() {
    super(...arguments);

    if (this.shouldDisplay) {
      this.appEvents.on(
        USER_DRAFTS_CHANGED_EVENT,
        this,
        this._updateDraftCount
      );
    }
  }

  teardown() {
    if (this.shouldDisplay) {
      this.appEvents.off(
        USER_DRAFTS_CHANGED_EVENT,
        this,
        this._updateDraftCount
      );
    }
  }

  _updateDraftCount() {
    this.draftCount = this.currentUser.draft_count;
  }

  get showCount() {
    return this.currentUser?.sidebarShowCountOfNewItems;
  }

  get name() {
    return "my-posts";
  }

  get route() {
    if (this._hasDraft) {
      return "userActivity.drafts";
    } else {
      return "userActivity.index";
    }
  }

  get currentWhen() {
    if (this._hasDraft) {
      return "userActivity.index userActivity.drafts";
    }
  }

  get model() {
    return this.currentUser;
  }

  get title() {
    if (this._hasDraft) {
      return i18n("sidebar.sections.community.links.my_posts.title_drafts");
    } else {
      return i18n("sidebar.sections.community.links.my_posts.title");
    }
  }

  get text() {
    if (this._hasDraft && this.currentUser?.new_new_view_enabled) {
      return i18n("sidebar.sections.community.links.my_posts.content_drafts");
    } else {
      return i18n(
        `sidebar.sections.community.links.${this.overridenName
          .toLowerCase()
          .replace(" ", "_")}.content`,
        { defaultValue: this.overridenName }
      );
    }
  }

  get badgeText() {
    if (!this.showCount || !this._hasDraft) {
      return;
    }

    if (this.currentUser.new_new_view_enabled) {
      return this.draftCount.toString();
    } else {
      return i18n("sidebar.sections.community.links.my_posts.draft_count", {
        count: this.draftCount,
      });
    }
  }

  get _hasDraft() {
    return this.draftCount > 0;
  }

  get defaultPrefixValue() {
    if (this._hasDraft && this.currentUser?.new_new_view_enabled) {
      return "pencil";
    }
    return "user";
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (this._hasDraft && !this.showCount) {
      return "circle";
    }
  }

  get shouldDisplay() {
    return this.currentUser;
  }
}
