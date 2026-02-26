import EmberObject from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowHouseAds extends DiscourseRoute {
  async model() {
    const data = await ajax("/admin/plugins/discourse-adplugin/house-ads");

    return {
      houseAds: trackedArray(
        data.house_ads.map((ad) => EmberObject.create(ad))
      ),
      houseAdsSettings: EmberObject.create(data.settings),
    };
  }
}
