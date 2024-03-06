import Route from "@ember/routing/route";

export default class AdminCustomizeThemesShowSchemaRoute extends Route {
  model(params) {
    const theme = this.modelFor("adminCustomizeThemesShow");
    const setting = theme.settings.findBy("setting", params.setting_name);

    return {
      data: setting.value,
      schema: setting.objects_schema,
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
