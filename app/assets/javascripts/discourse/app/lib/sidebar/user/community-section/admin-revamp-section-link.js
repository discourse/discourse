import { service } from "@ember/service";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import I18n from "discourse-i18n";

export default class AdminRevampSectionLink extends BaseSectionLink {
  @service siteSettings;

  get name() {
    return "admin-revamp";
  }

  get route() {
    return "admin-revamp";
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
    if (!this.currentUser) {
      return false;
    }

    return this.currentUser.use_admin_sidebar;
  }

  get defaultPrefixValue() {
    return "star";
  }
}
