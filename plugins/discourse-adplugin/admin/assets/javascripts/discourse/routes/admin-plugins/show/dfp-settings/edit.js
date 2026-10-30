import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDfpSettingsEdit extends DiscourseRoute {
  model({ id }) {
    const settings = this.modelFor("adminPlugins.show.dfpSettings").settings;
    const setting = settings.find((item) => item.id === Number(id));

    if (!setting) {
      return this.replaceWith("adminPlugins.show.dfpSettings.index");
    }

    return { setting, settings };
  }
}
