Discourse.DiscourseLogoComponent = Ember.Component.extend({
  linkUrl: function() {
    return Discourse.getURL("/");
  }.property(),

  showSmallLogo: function() {
    return !Discourse.Mobile.mobileView && this.get("minimized");
  }.property("minimized"),

  smallLogoUrl: function() {
    return Discourse.SiteSettings.logo_small_url;
  }.property(),

  bigLogoUrl: function() {
    return Discourse.SiteSettings.logo_url;
  }.property(),

  title: function() {
    return Discourse.SiteSettings.title;
  }.property()
});
