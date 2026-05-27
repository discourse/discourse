import Controller from "@ember/controller";
import { computed, set } from "@ember/object";

export default class AboutController extends Controller {
  @computed("siteSettings.faq_url.length")
  get faqOverridden() {
    return this.siteSettings?.faq_url?.length > 0;
  }

  @computed("siteSettings.rename_faq_to_guidelines")
  get renameFaqToGuidelines() {
    return this.siteSettings?.rename_faq_to_guidelines;
  }

  set renameFaqToGuidelines(value) {
    set(this, "siteSettings.rename_faq_to_guidelines", value);
  }
}
