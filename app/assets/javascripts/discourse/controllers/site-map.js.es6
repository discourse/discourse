import { url } from 'discourse/lib/computed';

export default Ember.ArrayController.extend({
  needs: ['application', 'header'],

  showBadgesLink: function(){return Discourse.SiteSettings.enable_badges;}.property(),
  showAdminLinks: Em.computed.alias('currentUser.staff'),

  faqUrl: function() {
    return Discourse.SiteSettings.faq_url ? Discourse.SiteSettings.faq_url : Discourse.getURL('/faq');
  }.property(),

  badgesUrl: url('/badges'),

  showKeyboardShortcuts: function(){
    return !Discourse.Mobile.mobileView && !this.capabilities.touch;
  }.property(),

  showMobileToggle: function(){
    return Discourse.Mobile.mobileView || (Discourse.SiteSettings.enable_mobile_theme && this.capabilities.touch);
  }.property(),

  mobileViewLinkTextKey: function() {
    return Discourse.Mobile.mobileView ? "desktop_view" : "mobile_view";
  }.property(),

  categories: function() {
    var hideUncategorized = !this.siteSettings.allow_uncategorized_topics,
        showSubcatList = this.siteSettings.show_subcategory_list,
        isStaff = Discourse.User.currentProp('staff');
    return Discourse.Category.list().reject(function(c) {
      if (showSubcatList && c.get('parent_category_id')) { return true; }
      if (hideUncategorized && c.get('isUncategorizedCategory') && !isStaff) { return true; }
      return false;
    });
  }.property(),

  actions: {
    keyboardShortcuts: function(){
      this.get('controllers.application').send('showKeyboardShortcutsHelp');
    },
    toggleMobileView: function() {
      Discourse.Mobile.toggleMobileView();
    }
  }
});
