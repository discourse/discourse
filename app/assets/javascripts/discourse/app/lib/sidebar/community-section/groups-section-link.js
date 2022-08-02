import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/community-section/base-section-link";

export default class GroupsSectionLink extends BaseSectionLink {
  get name() {
    return "groups";
  }

  get route() {
    return "groups";
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.groups.title");
  }

  get text() {
    return I18n.t("sidebar.sections.community.links.groups.content");
  }
}
