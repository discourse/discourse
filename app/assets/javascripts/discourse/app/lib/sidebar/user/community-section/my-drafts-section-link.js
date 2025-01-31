import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class MyDraftsSectionLink extends BaseSectionLink {
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
    if (!this.showCount || !this.hasDrafts) {
      return;
    }

    if (this.currentUser.new_new_view_enabled) {
      return this.draftCount.toString();
    } else {
      return i18n("sidebar.sections.community.links.my_drafts.draft_count", {
        count: this.draftCount,
      });
    }
  }

  get draftCount() {
    return this.currentUser?.get("draft_count");
  }

  get hasDrafts() {
    return this.draftCount > 0;
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (!this.showCount && this.hasDrafts) {
      return "circle";
    }
  }

  get shouldDisplay() {
    return this.currentUser;
  }

  get prefixValue() {
    return "far-pen-to-square";
  }
}
