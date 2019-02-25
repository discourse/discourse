/**
  Handles when you click the Site Settings tab in admin, but haven't
  chosen a category. It will redirect to the first category.
**/
export default Discourse.Route.extend({
  beforeModel() {
    this.replaceWith(
      "adminSiteSettingsCategory",
      this.controllerFor("adminSiteSettings").get("visibleSiteSettings")[0]
        .nameKey
    );
  }
});
