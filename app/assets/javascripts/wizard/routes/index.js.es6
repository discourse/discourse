import Route from "@ember/routing/route";
export default Route.extend({
  beforeModel() {
    const appModel = this.modelFor("application");
    this.replaceWith("step", appModel.start);
  }
});
