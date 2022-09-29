import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";

export default class AdminSectionLink extends BaseSectionLink {
  get name() {
    return "admin";
  }

  get route() {
    return "admin";
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.admin.content");
  }

  get text() {
    return I18n.t("sidebar.sections.community.links.admin.content");
  }

  get shouldDisplay() {
    return this.currentUser?.staff;
  }

  get prefixValue() {
    return "wrench";
  }
}
