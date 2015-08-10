import DiscourseURL from 'discourse/lib/url';
import { setting } from 'discourse/lib/computed';

export default Ember.Component.extend({
  classNames: ["title"],

  linkUrl: function() {
    return Discourse.getURL('/');
  }.property(),

  showSmallLogo: function() {
    return !Discourse.Mobile.mobileView && this.get("minimized");
  }.property("minimized"),

  showMobileLogo: function() {
    return Discourse.Mobile.mobileView && !Ember.isBlank(this.get('mobileBigLogoUrl'));
  }.property(),

  smallLogoUrl: setting('logo_small_url'),
  bigLogoUrl: setting('logo_url'),
  mobileBigLogoUrl: setting('mobile_logo_url'),
  title: setting('title'),

  click: function(e) {
    // if they want to open in a new tab, let it so
    if (e.shiftKey || e.metaKey || e.ctrlKey || e.which === 2) { return true; }

    e.preventDefault();

    DiscourseURL.routeTo('/');
    return false;
  }
});
