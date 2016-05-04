export default Ember.Controller.extend({
  sortProperties: ['count:desc', 'id'],

  sortedTags: Ember.computed.sort('model', 'sortProperties'),

  actions: {
    sortByCount() {
      this.set('sortProperties', ['count:desc', 'id']);
    },

    sortById() {
      this.set('sortProperties', ['id']);
    }
  }
});
