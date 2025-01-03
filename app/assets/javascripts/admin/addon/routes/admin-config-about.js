import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigAboutRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.community.sidebar_link.about_your_site");
  }

  model() {
    return ajax("/admin/config/site_settings.json", {
      data: {
        filter_area: "about",
      },
    });
  }
}
