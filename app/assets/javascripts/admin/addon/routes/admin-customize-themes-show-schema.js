import Route from "@ember/routing/route";

export default class AdminCustomizeThemesShowSchemaRoute extends Route {
  async model(params) {
    const theme = this.modelFor("adminCustomizeThemesShow");
    const setting = theme.settings.findBy("setting", params.setting_name);

    await setting.loadMetadata(theme.id);

    return {
      theme,
      setting,
    };
  }

  setupController() {
    super.setupController(...arguments);
    this.controllerFor("adminCustomizeThemes").set("editingTheme", true);

    this.controllerFor("adminCustomizeThemes.show").set(
      "editingThemeSetting",
      true
    );
  }

  deactivate() {
    this.controllerFor("adminCustomizeThemes").set("editingTheme", false);

    this.controllerFor("adminCustomizeThemes.show").set(
      "editingThemeSetting",
      false
    );
  }
}
