import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class AboutSectionLink extends BaseSectionLink {
  get name() {
    return "about";
  }

  get route() {
    return "about";
  }

  get title() {
    return i18n("sidebar.sections.community.links.about.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get defaultPrefixValue() {
    return "circle-info";
  }
}
