import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/user/community-section/base-section-link";

export default class BadgesSectionLink extends BaseSectionLink {
  get name() {
    return "badges";
  }

  get route() {
    return "badges";
  }

  get title() {
    return I18n.t("badges.title");
  }

  get text() {
    return I18n.t("badges.title");
  }
}
