import { tracked } from "@glimmer/tracking";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

const DRAFTS_CHANGED_EVENT = "user-drafts:changed";

export default class MyDraftsSectionLink extends BaseSectionLink {
  @tracked shouldDisplay = this._hasDraft;

  constructor() {
    super(...arguments);

    if (this.currentUser) {
      this.appEvents.on(DRAFTS_CHANGED_EVENT, this, this._updateDraftCount);
    }
  }

  get _hasDraft() {
    return this.currentUser?.draft_count > 0;
  }

  _updateDraftCount() {
    this.shouldDisplay = this.currentUser?.draft_count > 0;
  }

  get showCount() {
    return this.currentUser?.sidebarShowCountOfNewItems;
  }

  get name() {
    return "my-drafts";
  }

  get route() {
    return "userActivity.drafts";
  }

  get model() {
    return this.currentUser;
  }

  get title() {
    return i18n("sidebar.sections.community.links.my_drafts.title");
  }

  get text() {
    return i18n("sidebar.sections.community.links.my_drafts.content");
  }

  get badgeText() {
    if (!this.showCount || !this.shouldDisplay) {
      return;
    }

    if (this.currentUser.new_new_view_enabled) {
      return this.currentUser?.draft_count.toString();
    } else {
      return i18n("sidebar.sections.community.links.my_drafts.draft_count", {
        count: this.currentUser?.draft_count,
      });
    }
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (this.shouldDisplay && !this.showCount) {
      return "circle";
    }
  }

  get prefixValue() {
    return "far-pen-to-square";
  }
}
