import AdminCustomizeThemesEditRoute from "admin/routes/admin-customize-themes-edit";

export default class AdminConfigThemeEditRoute extends AdminCustomizeThemesEditRoute {
  themeIndexRoute = "adminConfig.customize.themes";
  themeEditRoute = "adminConfig.themeEdit";

  async model(params) {
    const wrapper = this.modelFor("adminConfig.themeEdit");

    if (wrapper?.model.id === parseInt(params.theme_id, 10)) {
      return {
        model: wrapper.model,
        target: params.target,
        field_name: params.field_name,
      };
    }

    const theme = await this.store.find("theme", params.theme_id);
    return {
      model: theme,
      target: params.target,
      field_name: params.field_name,
    };
  }
}
