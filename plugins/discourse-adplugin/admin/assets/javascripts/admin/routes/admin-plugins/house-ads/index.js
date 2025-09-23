import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsHouseAdsIndex extends DiscourseRoute {
  @service router;

  @action
  moreSettings() {
    this.router.transitionTo("adminSiteSettingsCategory", "ad_plugin");
  }
}
