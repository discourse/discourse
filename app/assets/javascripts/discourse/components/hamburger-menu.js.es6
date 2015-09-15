import computed from 'ember-addons/ember-computed-decorators';
export default Ember.Component.extend({
  classNames: ['hamburger-panel'],

  @computed('currentUser.read_faq')
  prioritizeFaq(readFaq) {
    // If it's a custom FAQ never prioritize it
    return Ember.isEmpty(this.siteSettings.faq_url) && !readFaq;
  },

  @computed()
  showKeyboardShortcuts() {
    return !Discourse.Mobile.mobileView && !this.capabilities.touch;
  },

  @computed()
  showMobileToggle() {
    return Discourse.Mobile.mobileView || (this.siteSettings.enable_mobile_theme && this.capabilities.touch);
  },

  @computed()
  mobileViewLinkTextKey() {
    return Discourse.Mobile.mobileView ? "desktop_view" : "mobile_view";
  },

  @computed()
  faqUrl() {
    return this.siteSettings.faq_url ? this.siteSettings.faq_url : Discourse.getURL('/faq');
  },

  _lookupCount(type) {
    const state = this.get('topicTrackingState');
    return state ? state.lookupCount(type) : 0;
  },

  @computed('topicTrackingState.messageCount')
  newCount() {
    return this._lookupCount('new');
  },

  @computed('topicTrackingState.messageCount')
  unreadCount() {
    return this._lookupCount('unread');
  },

  @computed()
  categories() {
    const hideUncategorized = !this.siteSettings.allow_uncategorized_topics;
    const showSubcatList = this.siteSettings.show_subcategory_list;
    const isStaff = Discourse.User.currentProp('staff');

    return Discourse.Category.list().reject((c) => {
      if (showSubcatList && c.get('parent_category_id')) { return true; }
      if (hideUncategorized && c.get('isUncategorizedCategory') && !isStaff) { return true; }
      return false;
    });
  },

  actions: {
    keyboardShortcuts() {
      this.sendAction('showKeyboardAction');
    },
    toggleMobileView() {
      Discourse.Mobile.toggleMobileView();
    }
  }
});
