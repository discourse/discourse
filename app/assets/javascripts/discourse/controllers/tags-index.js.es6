export default Ember.Controller.extend({
  sortProperties: ['count:desc', 'id'],

  canAdminTags: Ember.computed.alias("currentUser.staff"),

  actions: {
    sortByCount() {
      this.set('sortProperties', ['count:desc', 'id']);
    },

    sortById() {
      this.set('sortProperties', ['id']);
    }
  }
});
