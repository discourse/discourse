import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { dependentKeyCompat } from "@ember/object/compat";
import { isSettingVisible } from "discourse/admin/services/site-setting-store";

export default class AdminSiteSettingsCategoryController extends Controller {
  @controller adminSiteSettings;

  @tracked model;

  @dependentKeyCompat
  get filteredSiteSettings() {
    const filter = this.adminSiteSettings.activeFilter;
    return this.model?.filter((s) => isSettingVisible(s, filter));
  }

  set filteredSiteSettings(value) {
    this.model = value;
  }
}
