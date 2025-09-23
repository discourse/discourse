import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import Theme from "admin/models/theme";

export default class AdminConfigThemesAndComponentsThemesRoute extends DiscourseRoute {
  queryParams = {
    repoUrl: { replace: true },
    repoName: { replace: true },
  };

  async model(params) {
    const data = await ajax("/admin/config/customize/themes");
    return {
      themes: data.themes.map((theme) =>
        // TODO(osama) MEGA HACK. remove the __type and __state properties when
        // we have rebuilt the theme "show" page and stopped requiring all
        // themes/components be loaded for the page.
        // If we use the store to load the themes here, the logic in afterFindAll
        // interfers with the themes objects already loaded for the theme "show"
        // page and breaks it.
        // If we don't use the store (and remove the __type and __state props
        // here), then the save method on the theme model breaks because it
        // expects the theme to be a store object.
        Theme.create({ ...theme, __type: "theme", __state: "created" })
      ),
      repoUrl: params.repoUrl,
      repoName: params.repoName,
    };
  }

  titleToken() {
    return i18n("admin.config_areas.themes_and_components.themes.title");
  }
}
