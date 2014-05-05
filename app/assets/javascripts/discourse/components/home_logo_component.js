Discourse.HomeLogoComponent = Ember.Component.extend({
  classNames: ["title"],

  linkUrl: function() {
    return Discourse.getURL("/");
  }.property(),

  showSmallLogo: function() {
    return !Discourse.Mobile.mobileView && this.get("minimized");
  }.property("minimized"),

  smallLogoUrl: Discourse.computed.setting('logo_small_url'),
  bigLogoUrl: Discourse.computed.setting('logo_url'),
  title: Discourse.computed.setting('title'),

});
