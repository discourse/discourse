export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: [':header-dropdown-toggle', 'active'],

  active: Ember.computed.alias('toggleVisible'),

  actions: {
    toggle() {
      if (this.siteSettings.login_required && !this.currentUser) {
        this.sendAction('loginAction');
      } else {
        this.toggleProperty('toggleVisible');
      }
      this.appEvents.trigger('dropdowns:closeAll');
    }
  }
});
