import Controller from "@ember/controller";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { gt } from "@ember/object/computed";

export default Controller.extend({
  faqOverriden: gt("siteSettings.faq_url.length", 0),

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
  },
});
