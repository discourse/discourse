import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsHouseAdsShow extends DiscourseRoute {
  model(params) {
    if (params.id === "new") {
      return new TrackedObject({
        name: i18n("admin.adplugin.house_ads.new_name"),
        html: "",
        visible_to_logged_in_users: true,
        visible_to_anons: true,
      });
    } else {
      const houseAd = this.modelFor("adminPlugins.houseAds").find(
        (item) => item.id === parseInt(params.id, 10)
      );

      if (houseAd.groups && Array.isArray(houseAd.groups)) {
        houseAd.groups = houseAd.groups.map((g) => {
          return g.id;
        });
      }

      return new TrackedObject(houseAd);
    }
  }
}
