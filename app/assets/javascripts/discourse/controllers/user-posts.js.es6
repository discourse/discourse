import Controller from "@ember/controller";
export default Controller.extend({
  application: Ember.inject.controller(),

  _showFooter: function() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore")
});
