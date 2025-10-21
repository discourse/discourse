import Controller, { inject as controller } from "@ember/controller";
import { alias } from "@ember/object/computed";

export default class AdminPluginsHouseAdsIndexController extends Controller {
  @controller("adminPlugins.houseAds") adminPluginsHouseAds;

  @alias("adminPluginsHouseAds.model") houseAds;
  @alias("adminPluginsHouseAds.houseAdsSettings") adSettings;
}
