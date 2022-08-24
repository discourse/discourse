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
    return I18n.t("faq");
  }

  get text() {
    return I18n.t("faq");
  }
}
