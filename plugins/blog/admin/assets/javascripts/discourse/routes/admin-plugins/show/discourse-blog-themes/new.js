import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const DEFAULT_THEME_ID = "default";

export default class BlogThemesNewRoute extends DiscourseRoute {
  queryParams = { from: { refreshModel: true } };

  async model({ from }) {
    const { themes, active } = await ajax("/admin/plugins/blog/themes.json");
    const base =
      themes.find((theme) => theme.id === from) ??
      themes.find((theme) => theme.id === DEFAULT_THEME_ID) ??
      active;

    return {
      active,
      sources: themes,
      from: base.id,
      theme: {
        ...base,
        id: null,
        revision: null,
        source: null,
        preset: false,
        locally_modified: false,
        preview_url: null,
        name:
          base.id === DEFAULT_THEME_ID
            ? i18n("blog.admin.new_theme_name")
            : i18n("blog.admin.customized_theme_name", { name: base.name }),
      },
    };
  }

  // Query params are sticky, so a later plain "New theme" would otherwise
  // reuse the last starting point.
  resetController(controller, isExiting) {
    if (isExiting) {
      controller.from = null;
    }
  }
}
