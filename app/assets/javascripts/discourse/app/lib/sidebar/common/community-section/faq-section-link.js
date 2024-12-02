import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { i18n } from "discourse-i18n";

export default class FAQSectionLink extends BaseSectionLink {
  get renameToGuidelines() {
    return (
      this.siteSettings.experimental_rename_faq_to_guidelines && !this.href
    );
  }

  get name() {
    return this.renameToGuidelines ? "guidelines" : "faq";
  }

  get route() {
    return this.renameToGuidelines ? "guidelines" : "faq";
  }

  get href() {
    return this.siteSettings.faq_url;
  }

  get title() {
    if (this.renameToGuidelines) {
      return i18n("sidebar.sections.community.links.guidelines.title");
    } else {
      return i18n("sidebar.sections.community.links.faq.title");
    }
  }

  get text() {
    const name = this.renameToGuidelines ? "Guidelines" : this.overridenName;

    return i18n(
      `sidebar.sections.community.links.${name.toLowerCase()}.content`,
      { defaultValue: name }
    );
  }

  get defaultPrefixValue() {
    return "circle-question";
  }
}
