import { trackedObject } from "@ember/reactive/collections";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowHouseAdsShow extends DiscourseRoute {
  model(params) {
    const parentModel = this.modelFor("adminPlugins.show.houseAds");

    if (params.id === "new") {
      return trackedObject({
        name: null,
        html: null,
        visible_to_logged_in_users: true,
        visible_to_anons: true,
      });
    } else {
      const houseAd = parentModel.houseAds.find(
        (item) => item.id === parseInt(params.id, 10)
      );

      if (!houseAd) {
        return this.replaceWith("adminPlugins.show.houseAds.index");
      }

      if (houseAd.groups && Array.isArray(houseAd.groups)) {
        houseAd.groups = houseAd.groups.map((g) =>
          typeof g === "object" && g !== null ? g.id : g
        );
      }

      return trackedObject(houseAd);
    }
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    const parentModel = this.modelFor("adminPlugins.show.houseAds");
    controller.houseAds = parentModel.houseAds;
  }
}
