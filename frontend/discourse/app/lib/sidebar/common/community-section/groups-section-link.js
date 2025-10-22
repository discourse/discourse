import { service } from "@ember/service";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class GroupsSectionLink extends BaseSectionLink {
  @service siteSettings;

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
      `sidebar.sections.community.links.${this.overriddenName.toLowerCase()}.content`,
      { defaultValue: this.overriddenName }
    );
  }

  get shouldDisplay() {
    return this.siteSettings.enable_group_directory;
  }

  get defaultPrefixValue() {
    return "user-group";
  }
}
