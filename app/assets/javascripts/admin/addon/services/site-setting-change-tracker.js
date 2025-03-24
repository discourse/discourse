import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";

export default class SiteSettingChangeTracker extends Service {
  @tracked dirtySiteSettings = new TrackedSet();

  add(setting) {
    this.dirtySiteSettings.add(setting.label);
  }

  remove(setting) {
    this.dirtySiteSettings.delete(setting.label);
  }

  get count() {
    this.dirtySiteSettings.size;
  }
}
