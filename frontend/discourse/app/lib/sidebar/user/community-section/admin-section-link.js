import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class AdminSectionLink extends BaseSectionLink {
  get name() {
    return "admin";
  }

  get route() {
    return "admin";
  }

  get title() {
    return i18n("sidebar.sections.community.links.admin.content");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overriddenName.toLowerCase()}.content`,
      { defaultValue: this.overriddenName }
    );
  }

  get shouldDisplay() {
    return !!this.currentUser?.staff;
  }

  get defaultPrefixValue() {
    return "wrench";
  }
}
