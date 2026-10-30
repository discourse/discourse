import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class BlogThemesNewRoute extends DiscourseRoute {
  async model() {
    const { active } = await ajax("/blog-editor/themes.json");
    return {
      active,
      theme: {
        ...active,
        id: null,
        revision: null,
        source: null,
        preview_url: null,
        name: i18n("blog.admin.new_theme_name"),
      },
    };
  }
}
