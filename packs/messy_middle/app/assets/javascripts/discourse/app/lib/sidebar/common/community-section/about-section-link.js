import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";

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
    return I18n.t("sidebar.sections.community.links.about.content");
  }

  get prefixValue() {
    return "info-circle";
  }
}
