import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    const model = this.modelFor("user").get("userDraftsStream");
    model.reset();
    return model.findItems(this.site).then(() => model);
  },

  renderTemplate() {
    this.render("user_stream");
  },

  setupController(controller, model) {
    controller.set("model", model);
  },

  activate() {
    this.appEvents.on("draft:destroyed", this, this.refresh);
  },

  deactivate() {
    this.appEvents.off("draft:destroyed", this, this.refresh);
  },

  actions: {
    didTransition() {
      this.controllerFor("user-activity")._showFooter();
      return true;
    },
  },
});
