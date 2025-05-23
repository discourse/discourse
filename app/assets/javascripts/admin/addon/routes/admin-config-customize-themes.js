import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigThemesAndComponentsThemesRoute extends DiscourseRoute {
  queryParams = {
    repoUrl: { replace: true },
    repoName: { replace: true },
  };

  titleToken() {
    return i18n("admin.config_areas.themes_and_components.themes.title");
  }

  async model(params) {
    return {
      themes: (
        await this.store.findAll("theme", {
          useConfigAreaEndpoint: true,
        })
      ).content,
      repoUrl: params.repoUrl,
      repoName: params.repoName,
    };
  }
}
