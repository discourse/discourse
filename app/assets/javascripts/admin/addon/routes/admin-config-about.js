import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminConfigAboutRoute extends Route {
  model() {
    return ajax("/admin/config/site_settings.json", {
      data: {
        filter_area: "about",
      },
    });
  }
}
