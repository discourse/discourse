export default Ember.Component.extend({
  classNames: ["title"],

  linkUrl: function() {
    return Discourse.getURL('/');
  }.property(),

  showSmallLogo: function() {
    return !Discourse.Mobile.mobileView && this.get("minimized");
  }.property("minimized"),

  smallLogoUrl: Discourse.computed.setting('logo_small_url'),
  bigLogoUrl: Discourse.computed.setting('logo_url'),
  title: Discourse.computed.setting('title'),

  click: function(e) {
    e.preventDefault();

    // When you click the logo, never use a cached list
    var session = Discourse.Session.current();
    session.setProperties({topicList: null, topicListScrollPos: null});

    Discourse.URL.routeTo('/');
    return false;
  }
});
