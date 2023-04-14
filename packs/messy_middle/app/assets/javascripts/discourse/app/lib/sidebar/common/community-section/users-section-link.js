import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";

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

  get shouldDisplay() {
    return (
      this.siteSettings.enable_user_directory &&
      (this.currentUser || !this.siteSettings.hide_user_profiles_from_public)
    );
  }

  get prefixValue() {
    return "users";
  }
}
