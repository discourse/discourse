import EmberObject from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowHouseAds extends DiscourseRoute {
  async model() {
    const data = await ajax("/admin/plugins/discourse-adplugin/house-ads");

    return {
      houseAds: new TrackedArray(
        data.house_ads.map((ad) => EmberObject.create(ad))
      ),
      houseAdsSettings: EmberObject.create(data.settings),
    };
  }
}
