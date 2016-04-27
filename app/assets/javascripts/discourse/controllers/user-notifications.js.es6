export default Ember.ArrayController.extend({
  needs: ['application'],

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore"),

  currentPath: Em.computed.alias('controllers.application.currentPath'),

  actions: {
    resetNew() {
      Discourse.ajax('/notifications/mark-read', { method: 'PUT' }).then(() => {
        this.setEach('read', true);
      });
    },

    loadMore() {
      this.get('model').loadMore();
    }
  }
});
