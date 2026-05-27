import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowHouseAdsIndex extends DiscourseRoute {
  model() {
    return this.modelFor("adminPlugins.show.houseAds");
  }
}
