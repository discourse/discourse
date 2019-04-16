import { emailValid } from "discourse/lib/utilities";

export default Ember.Controller.extend({
  faqOverriden: Ember.computed.gt("siteSettings.faq_url.length", 0),

  contactInfo: function() {
    const contact_url = this.siteSettings.contact_url;
    if (contact_url) {
      return I18n.t("about.contact_info", {
        contact_info:
          emailValid(contact_url)
            ? contact_url
            : ("<a href='" +
              contact_url +
              "' target='_blank'>" +
              contact_url +
              "</a>")
      });
    } else if (this.siteSettings.contact_email) {
      return I18n.t("about.contact_info", {
        contact_info: this.siteSettings.contact_email
      });
    } else {
      return null;
    }
  }.property()
});
