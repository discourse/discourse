import SiteSetting from "admin/models/site-setting";

export default Discourse.Route.extend({
  queryParams: {
    filter: { replace: true }
  },

  model() {
    return SiteSetting.findAll();
  },

  afterModel(siteSettings) {
    const controller = this.controllerFor("adminSiteSettings");

    if (!controller.get("visible")) {
      controller.set("visible", siteSettings);
    }
  }
});
