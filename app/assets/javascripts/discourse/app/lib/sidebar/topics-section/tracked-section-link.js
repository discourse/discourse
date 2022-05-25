import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/topics-section/base-section-link";

export default class TrackedSectionLink extends BaseSectionLink {
  get name() {
    return "tracked";
  }

  get route() {
    return "discovery.latest";
  }

  get query() {
    return { f: "tracked" };
  }

  get title() {
    return I18n.t("sidebar.sections.topics.links.tracked.title");
  }

  get text() {
    return I18n.t("sidebar.sections.topics.links.tracked.content");
  }
}
