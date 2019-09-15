export default Ember.Component.extend({
  actions: {
    authenticateSecurityKey() {
      this.attrs['action']();
    }
  }
});
