import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import I18n from "discourse-i18n";

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
    return I18n.t(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get defaultPrefixValue() {
    return "question-circle";
  }
}
