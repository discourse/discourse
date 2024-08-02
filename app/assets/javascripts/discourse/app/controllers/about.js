import Controller from "@ember/controller";
import { alias, gt } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class AboutController extends Controller {
  @gt("siteSettings.faq_url.length", 0) faqOverridden;

  @alias("siteSettings.experimental_rename_faq_to_guidelines")
  renameFaqToGuidelines;

  @discourseComputed("model.contact_url", "model.contact_email")
  contactInfo(url, email) {
    if (url) {
      return I18n.t("about.contact_info", {
        contact_info: `<a href='${url}' target='_blank'>${url}</a>`,
      });
    } else if (email) {
      return I18n.t("about.contact_info", {
        contact_info: email,
      });
    } else {
      return null;
    }
  }
}
