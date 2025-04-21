import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class GroupsSectionLink extends BaseSectionLink {
  get name() {
    return "groups";
  }

  get route() {
    return "groups";
  }

  get title() {
    return i18n("sidebar.sections.community.links.groups.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get shouldDisplay() {
    return this.siteSettings.enable_group_directory;
  }

  get defaultPrefixValue() {
    return "user-group";
  }
}
