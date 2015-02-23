import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend({
  faqOverriden: function() {
    return !(this.siteSettings.faq_url.length === 0);
  }.property(),

  contactInfo: function() {
    if (Discourse.SiteSettings.contact_email) {
      return I18n.t('about.contact_info', {contact_email: Discourse.SiteSettings.contact_email});
    } else {
      return null;
    }
  }.property()
});
