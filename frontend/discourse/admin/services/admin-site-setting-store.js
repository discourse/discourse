import { trackedMap, trackedSet } from "@ember/reactive/collections";
import Service from "@ember/service";
import { isSettingValueTrue } from "discourse/admin/models/site-setting";

function normalize(value) {
  return (value ?? "").toLowerCase().replace(/_/g, " ").trim();
}

export default class AdminSiteSettingStore extends Service {
  byName = trackedMap();
  #revealed = trackedSet();

  register(settings) {
    settings.forEach((setting) => {
      this.byName.set(setting.setting, setting);
    });
    this.#computeInitialReveals(settings);
  }

  get(name) {
    return this.byName.get(name);
  }

  isRevealed(setting) {
    return this.#revealed.has(setting.setting);
  }

  isVisible(setting, activeFilter = "") {
    if (setting.depends_behavior !== "hidden") {
      return true;
    }
    if (this.#revealed.has(setting.setting)) {
      return true;
    }
    const filter = normalize(activeFilter);
    return filter !== "" && filter === normalize(setting.setting);
  }

  reveal(name) {
    this.byName.forEach((setting) => {
      if (
        setting.depends_behavior === "hidden" &&
        setting.depends_on?.includes(name)
      ) {
        this.#revealed.add(setting.setting);
      }
    });
  }

  #computeInitialReveals(settings) {
    settings.forEach((setting) => {
      if (
        setting.depends_behavior !== "hidden" ||
        !setting.depends_on?.length
      ) {
        return;
      }
      const allTrue = setting.depends_on.every((name) => {
        const parent = this.byName.get(name);
        return parent ? isSettingValueTrue(parent.value) : true;
      });
      if (allTrue) {
        this.#revealed.add(setting.setting);
      } else {
        this.#revealed.delete(setting.setting);
      }
    });
  }
}
