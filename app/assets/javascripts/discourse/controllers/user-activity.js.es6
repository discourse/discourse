export default Ember.ObjectController.extend({
  needs: ["application"],

  _showFooter: function() {
    var showFooter;
    if (this.get("userActionType")) {
      var stat = _.find(this.get("stats"), { action_type: this.get("userActionType") });
      showFooter = stat && stat.count <= this.get("stream.itemsLoaded");
    } else {
      showFooter = this.get("statsCountNonPM") <= this.get("stream.itemsLoaded");
    }
    this.set("controllers.application.showFooter", showFooter);
  }.observes("userActionType", "stream.itemsLoaded")

});
