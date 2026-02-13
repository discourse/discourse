import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";

export default class AdminPluginsHouseAdsIndexController extends Controller {
  @controller("adminPlugins.houseAds") adminPluginsHouseAds;

  @tracked currentTab = "ads";
  @alias("adminPluginsHouseAds.model") houseAds;
  @alias("adminPluginsHouseAds.houseAdsSettings") adSettings;

  @action
  onTabChange(tab, event) {
    event.preventDefault();
    this.currentTab = tab;
  }
}
