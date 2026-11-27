import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowDfpSettingsNew extends DiscourseRoute {
  model() {
    return {
      setting: {
        id: null,
        category_id: null,
        gam_adunit: "",
        gam_keywords: "",
        gtm_taxonomy: "",
      },
      settings: this.modelFor("adminPlugins.show.dfpSettings").settings,
    };
  }
}
