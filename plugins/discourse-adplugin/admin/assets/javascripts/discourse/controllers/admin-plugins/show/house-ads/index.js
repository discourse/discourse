import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class AdminPluginsShowHouseAdsIndexController extends Controller {
  @service router;

  @tracked currentTab = "ads";

  get houseAds() {
    return this.model.houseAds;
  }

  get adSettings() {
    return this.model.houseAdsSettings;
  }

  @action
  onTabChange(tab, event) {
    event.preventDefault();
    this.currentTab = tab;
  }

  @action
  moreSettings() {
    this.router.transitionTo("adminSiteSettingsCategory", "ad_plugin");
  }
}
