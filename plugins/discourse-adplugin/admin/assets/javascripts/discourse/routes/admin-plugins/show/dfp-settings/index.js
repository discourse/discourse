import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDfpSettingsIndex extends DiscourseRoute {
  model() {
    return this.modelFor("adminPlugins.show.dfpSettings");
  }
}
