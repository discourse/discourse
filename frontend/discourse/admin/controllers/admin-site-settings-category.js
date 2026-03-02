import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { dependentKeyCompat } from "@ember/object/compat";

export default class AdminSiteSettingsCategoryController extends Controller {
  @tracked model;

  @dependentKeyCompat
  get filteredSiteSettings() {
    return this.model;
  }

  set filteredSiteSettings(value) {
    this.model = value;
  }
}
