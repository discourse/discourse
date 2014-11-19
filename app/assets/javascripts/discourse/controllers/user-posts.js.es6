export default Ember.ObjectController.extend({
  needs: ["application"],

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("canLoadMore"))
  }.observes("canLoadMore")
});
