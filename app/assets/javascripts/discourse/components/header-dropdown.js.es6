export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: [':header-dropdown-toggle', 'active'],

  active: Ember.computed.alias('toggleVisible'),

  actions: {
    toggle() {

      if (this.siteSettings.login_required && !this.currentUser) {
        this.sendAction('loginAction');
      } else {
        if (this.site.mobileView && this.get('mobileAction')) {
          this.sendAction('mobileAction');
          return;
        }

        if (this.get('action')) {
          this.sendAction('action');
        } else {
          this.toggleProperty('toggleVisible');
        }
      }
      this.appEvents.trigger('dropdowns:closeAll');
    }
  }
});
