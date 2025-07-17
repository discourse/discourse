import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class FilterSectionLink extends BaseSectionLink {
  get name() {
    return "filter";
  }

  get route() {
    return "discovery.filter";
  }

  get title() {
    return i18n("sidebar.sections.community.links.filter.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get shouldDisplay() {
    return true;
  }

  get defaultPrefixValue() {
    return "filter";
  }
}
