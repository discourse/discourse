import I18n from "I18n";
import { tracked } from "@glimmer/tracking";

import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { UNREAD_LIST_DESTINATION } from "discourse/controllers/preferences/sidebar";

const USER_DRAFTS_CHANGED_EVENT = "user-drafts:changed";

export default class MyPostsSectionLink extends BaseSectionLink {
  @tracked draftCount = this.currentUser?.draft_count;
  @tracked hideCount =
    this.currentUser?.sidebarListDestination !== UNREAD_LIST_DESTINATION;

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
      return I18n.t("sidebar.sections.community.links.my_posts.title_drafts");
    } else {
      return I18n.t("sidebar.sections.community.links.my_posts.title");
    }
  }

  get text() {
    if (this._hasDraft && this.currentUser?.new_new_view_enabled) {
      return I18n.t("sidebar.sections.community.links.my_posts.content_drafts");
    } else {
      return I18n.t("sidebar.sections.community.links.my_posts.content");
    }
  }

  get badgeText() {
    if (this._hasDraft && this.currentUser?.new_new_view_enabled) {
      return this.draftCount.toString();
    }
    if (this._hasDraft && !this.hideCount) {
      return I18n.t("sidebar.sections.community.links.my_posts.draft_count", {
        count: this.draftCount,
      });
    }
  }

  get _hasDraft() {
    return this.draftCount > 0;
  }

  get prefixValue() {
    if (this._hasDraft && this.currentUser?.new_new_view_enabled) {
      return "pencil-alt";
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
    if (this._hasDraft && this.hideCount) {
      return "circle";
    }
  }

  get shouldDisplay() {
    return this.currentUser;
  }
}
