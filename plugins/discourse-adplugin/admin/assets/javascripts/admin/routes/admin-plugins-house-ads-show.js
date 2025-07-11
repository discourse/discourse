import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsHouseAdsShow extends DiscourseRoute {
  model(params) {
    if (params.ad_id === "new") {
      return new TrackedObject({
        name: i18n("admin.adplugin.house_ads.new_name"),
        html: "",
        visible_to_logged_in_users: true,
        visible_to_anons: true,
      });
    } else {
      return new TrackedObject(
        this.modelFor("adminPlugins.houseAds").findBy(
          "id",
          parseInt(params.ad_id, 10)
        )
      );
    }
  }
}
