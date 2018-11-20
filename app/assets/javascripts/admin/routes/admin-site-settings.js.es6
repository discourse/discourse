import SiteSetting from "admin/models/site-setting";

export default Discourse.Route.extend({
  queryParams: {
    filter: { replace: true }
  },

  model() {
    return SiteSetting.findAll();
  },

  afterModel(siteSettings) {
    this.controllerFor("adminSiteSettings").set(
      "allSiteSettings",
      siteSettings
    );
  }
});
