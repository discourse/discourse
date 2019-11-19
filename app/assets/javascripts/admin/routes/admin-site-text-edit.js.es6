import Route from "@ember/routing/route";
export default Route.extend({
  model(params) {
    return this.store.find("site-text", params.id);
  },

  setupController(controller, siteText) {
    controller.setProperties({ siteText, saved: false });
  }
});
