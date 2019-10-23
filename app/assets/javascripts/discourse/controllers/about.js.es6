import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  faqOverriden: Ember.computed.gt("siteSettings.faq_url.length", 0),

  @computed
  contactInfo() {
    if (this.siteSettings.contact_url) {
      return I18n.t("about.contact_info", {
        contact_info:
          "<a href='" +
          this.siteSettings.contact_url +
          "' target='_blank'>" +
          this.siteSettings.contact_url +
          "</a>"
      });
    } else if (this.siteSettings.contact_email) {
      return I18n.t("about.contact_info", {
        contact_info: this.siteSettings.contact_email
      });
    } else {
      return null;
    }
  }
});
