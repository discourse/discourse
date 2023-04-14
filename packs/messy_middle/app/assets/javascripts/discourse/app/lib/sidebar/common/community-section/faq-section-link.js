import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";

export default class FAQSectionLink extends BaseSectionLink {
  get name() {
    return "faq";
  }

  get route() {
    return "faq";
  }

  get href() {
    return this.siteSettings.faq_url;
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.faq.title");
  }

  get text() {
    return I18n.t("sidebar.sections.community.links.faq.content");
  }

  get prefixValue() {
    return "question-circle";
  }
}
