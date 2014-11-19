export default Em.Mixin.create({
  actions: {
    didTransition: function() {
      var self = this;
      Em.run.schedule("afterRender", function() {
        self.controllerFor("application").set("showFooter", true);
      });
      return true;
    },

    willTransition: function() {
      this.controllerFor("application").set("showFooter", false);
      return true;
    }
  }
})
