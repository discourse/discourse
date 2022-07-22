import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/community-section/base-section-link";

export default class UsersSectionLink extends BaseSectionLink {
  get name() {
    return "users";
  }

  get route() {
    return "users";
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.users.title");
  }

  get text() {
    return I18n.t("sidebar.sections.community.links.users.content");
  }
}
