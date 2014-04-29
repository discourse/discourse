Discourse.SiteMapController = Ember.ArrayController.extend(Discourse.HasCurrentUser, {
  itemController: "siteMapCategory",

  showAdminLinks: Em.computed.alias('currentUser.staff'),
  flaggedPostsCount: Em.computed.alias("currentUser.site_flagged_posts_count"),

  faqUrl: function() {
    return Discourse.SiteSettings.faq_url ? Discourse.SiteSettings.faq_url : Discourse.getURL('/faq');
  }.property(),

  showMobileToggle: Discourse.computed.setting('enable_mobile_theme'),

  mobileViewLinkTextKey: function() {
    return Discourse.Mobile.mobileView ? "desktop_view" : "mobile_view";
  }.property(),

  categories: function() {
    if (Discourse.SiteSettings.allow_uncategorized_topics) {
      return Discourse.Category.list();
    } else {
      // Exclude the uncategorized category if it's empty
      return Discourse.Category.list().reject(function(c) {
        return c.get('isUncategorizedCategory') && !Discourse.User.currentProp('staff');
      });
    }
  }.property(),

  actions: {
    toggleMobileView: function() {
      Discourse.Mobile.toggleMobileView();
    }
  }
});
