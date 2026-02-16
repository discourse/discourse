import Controller, { inject as controller } from "@ember/controller";
import { alias } from "@ember/object/computed";

export default class adminPluginsHouseAdsShow extends Controller {
  @controller("adminPlugins.houseAds") houseAdsController;

  @alias("houseAdsController.model") houseAds;
}
