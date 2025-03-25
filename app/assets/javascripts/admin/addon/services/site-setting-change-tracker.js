import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";

export default class SiteSettingChangeTracker extends Service {
  @tracked dirtySiteSettings = new TrackedSet();

  add(settingComponent) {
    this.dirtySiteSettings.add(settingComponent);
  }

  remove(settingComponent) {
    this.dirtySiteSettings.delete(settingComponent);
  }

  discard() {
    this.dirtySiteSettings.forEach((siteSetting) => siteSetting.cancel());
  }

  get count() {
    return this.dirtySiteSettings.size;
  }
}
