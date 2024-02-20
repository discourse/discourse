import Route from "@ember/routing/route";

export default class AdminCustomizeThemesSchemaRoute extends Route {
  setupController() {
    super.setupController(...arguments);
    this.controllerFor("adminCustomizeThemes").set("editingTheme", true);
  }
}
