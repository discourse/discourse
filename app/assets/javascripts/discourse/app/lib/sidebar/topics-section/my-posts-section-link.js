import I18n from "I18n";
import { tracked } from "@glimmer/tracking";

import BaseSectionLink from "discourse/lib/sidebar/topics-section/base-section-link";

const USER_DRAFTS_CHANGED_EVENT = "user-drafts:changed";

export default class MyPostsSectionLink extends BaseSectionLink {
  @tracked draftCount = this.currentUser.draft_count;

  constructor() {
    super(...arguments);
    this.appEvents.on(USER_DRAFTS_CHANGED_EVENT, this, this._updateDraftCount);
  }

  teardown() {
    this.appEvents.off(USER_DRAFTS_CHANGED_EVENT, this, this._updateDraftCount);
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
    return I18n.t("sidebar.sections.topics.links.my_posts.title");
  }

  get text() {
    return I18n.t("sidebar.sections.topics.links.my_posts.content");
  }

  get badgeText() {
    if (this._hasDraft) {
      return I18n.t("sidebar.sections.topics.links.my_posts.draft_count", {
        count: this.draftCount,
      });
    }
  }

  get _hasDraft() {
    return this.draftCount > 0;
  }
}
