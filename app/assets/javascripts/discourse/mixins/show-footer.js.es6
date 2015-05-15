export default Em.Mixin.create({
  actions: {
    didTransition() {
      Em.run.schedule("afterRender", () => {
        this.controllerFor("application").set("showFooter", true);
      });
      return true;
    },

    willTransition() {
      this.controllerFor("application").set("showFooter", false);
      return true;
    }
  }
});
