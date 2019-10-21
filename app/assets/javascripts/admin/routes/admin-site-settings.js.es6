import DiscourseRoute from "discourse/routes/discourse";
import SiteSetting from "admin/models/site-setting";

export default DiscourseRoute.extend({
  queryParams: {
    filter: { replace: true }
  },

  model() {
    return SiteSetting.findAll();
  },

  afterModel(siteSettings) {
    const controller = this.controllerFor("adminSiteSettings");

    if (!controller.get("visibleSiteSettings")) {
      controller.set("visibleSiteSettings", siteSettings);
    }
  },

  actions: {
    refreshAll() {
      SiteSetting.findAll().then(settings => {
        this.controllerFor("adminSiteSettings").set("model", settings);
      });
    }
  }
});
