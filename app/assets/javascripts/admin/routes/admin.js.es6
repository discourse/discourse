export default Discourse.Route.extend({
  titleToken() {
    return I18n.t("admin_title");
  },

  activate() {
    this.controllerFor("application").setProperties({
      showTop: false,
      showFooter: false
    });
  },

  deactivate() {
    this.controllerFor("application").set("showTop", true);
  }
});
