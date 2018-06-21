export default Ember.Controller.extend({
  sortProperties: ["count:desc", "id"],
  tagsForUser: null,
  sortedByCount: true,
  sortedByName: false,

  actions: {
    sortByCount() {
      this.setProperties({
        sortProperties: ["count:desc", "id"],
        sortedByCount: true,
        sortedByName: false
      });
    },

    sortById() {
      this.setProperties({
        sortProperties: ["id"],
        sortedByCount: false,
        sortedByName: true
      });
    }
  }
});
