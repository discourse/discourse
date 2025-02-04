import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class UsersSectionLink extends BaseSectionLink {
  get name() {
    return "users";
  }

  get route() {
    return "users";
  }

  get title() {
    return i18n("sidebar.sections.community.links.users.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get shouldDisplay() {
    return (
      this.siteSettings.enable_user_directory &&
      (this.currentUser || !this.siteSettings.hide_user_profiles_from_public)
    );
  }

  get defaultPrefixValue() {
    return "users";
  }
}
