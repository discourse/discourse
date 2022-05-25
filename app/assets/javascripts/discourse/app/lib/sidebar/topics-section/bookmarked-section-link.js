import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/topics-section/base-section-link";

export default class BookmarkedSectionLink extends BaseSectionLink {
  get name() {
    return "bookmarked";
  }

  get route() {
    return "userActivity.bookmarks";
  }

  get model() {
    return this.currentUser;
  }

  get title() {
    return I18n.t("sidebar.sections.topics.links.bookmarked.title");
  }

  get text() {
    return I18n.t("sidebar.sections.topics.links.bookmarked.content");
  }
}
