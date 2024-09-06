import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import I18n from "discourse-i18n";

export default class AboutSectionLink extends BaseSectionLink {
  get name() {
    return "about";
  }

  get route() {
    return "about";
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.about.title");
  }

  get text() {
    return I18n.t(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get defaultPrefixValue() {
    return "circle-info";
  }
}
