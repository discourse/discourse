export default Ember.Controller.extend({
  needs: ["application"],

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore")
});
