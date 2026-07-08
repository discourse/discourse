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
    if (this.#hasValueDependencies(setting)) {
      return this.dependenciesSatisfied(setting);
    }

    return (
      this.#revealed.has(setting.setting) || this.dependenciesSatisfied(setting)
    );
  }

  isVisible(setting, activeFilter = "") {
    const filter = normalize(activeFilter);

    if (this.#isInlineDependent(setting)) {
      return false;
    }

    if (setting.depends_behavior !== "hidden") {
      return true;
    }
    if (this.isRevealed(setting)) {
      return true;
    }
    return filter !== "" && filter === normalize(setting.setting);
  }

  inlineDependentSettings(setting) {
    return Array.from(this.byName.values()).filter(
      (dependentSetting) =>
        this.#isInlineDependent(dependentSetting) &&
        dependentSetting.depends_on?.includes(setting.setting) &&
        this.dependenciesSatisfied(dependentSetting)
    );
  }

  dependenciesSatisfied(setting) {
    if (!setting.depends_on?.length) {
      return true;
    }

    return setting.depends_on.every((name) => {
      const parent = this.byName.get(name);

      if (!parent) {
        return true;
      }

      const parentValue = parent.buffered?.get("value") ?? parent.value;
      const allowedValues = setting.depends_on_values?.[name];

      if (allowedValues) {
        return allowedValues.map(String).includes(String(parentValue));
      }

      return isSettingValueTrue(parentValue);
    });
  }

  reveal(name) {
    this.byName.forEach((setting) => {
      if (
        setting.depends_behavior === "hidden" &&
        setting.depends_on?.includes(name) &&
        !this.#hasValueDependencies(setting)
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
      if (this.#hasValueDependencies(setting)) {
        this.#revealed.delete(setting.setting);
      } else if (this.dependenciesSatisfied(setting)) {
        this.#revealed.add(setting.setting);
      } else {
        this.#revealed.delete(setting.setting);
      }
    });
  }

  #hasValueDependencies(setting) {
    return Object.keys(setting.depends_on_values ?? {}).length > 0;
  }

  #isInlineDependent(setting) {
    return (
      setting.depends_behavior === "hidden" &&
      setting.dependent_setting_display === "inline"
    );
  }
}
