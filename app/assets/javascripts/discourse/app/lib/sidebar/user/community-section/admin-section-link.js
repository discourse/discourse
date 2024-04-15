import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import I18n from "discourse-i18n";

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
    return I18n.t(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get shouldDisplay() {
    return !!this.currentUser?.staff;
  }

  get defaultPrefixValue() {
    return "wrench";
  }
}
