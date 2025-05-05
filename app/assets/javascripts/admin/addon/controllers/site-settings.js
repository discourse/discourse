import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class SiteSettingsController extends Controller {
  @service router;

  @action
  selectCategory(event) {
    const selectedCategory = event.target.value;
    this.router.transitionTo("adminSiteSettingsCategory", selectedCategory);
  }
}
