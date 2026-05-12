import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";

export default class AdminSiteSettingsCategoryController extends Controller {
  @service adminSiteSettingStore;
  @controller adminSiteSettings;

  @tracked model;

  @dependentKeyCompat
  get filteredSiteSettings() {
    const filter = this.adminSiteSettings.activeFilter;
    return this.model?.filter((setting) =>
      this.adminSiteSettingStore.isVisible(setting, filter)
    );
  }

  set filteredSiteSettings(value) {
    this.model = value;
  }
}
