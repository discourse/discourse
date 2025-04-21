import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class BadgesSectionLink extends BaseSectionLink {
  get name() {
    return "badges";
  }

  get route() {
    return "badges";
  }

  get title() {
    return i18n("sidebar.sections.community.links.badges.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get shouldDisplay() {
    return this.siteSettings.enable_badges;
  }

  get defaultPrefixValue() {
    return "certificate";
  }
}
