import { trackedMap } from "@ember/reactive/collections";
import Service from "@ember/service";
import { isSettingValueTrue } from "discourse/admin/models/site-setting";

function normalize(value) {
  return (value ?? "").toLowerCase().replace(/_/g, " ").trim();
}

export function isSettingVisible(setting, activeFilter = "") {
  if (setting.depends_behavior !== "hidden") {
    return true;
  }
  if (setting.revealed) {
    return true;
  }
  const filter = normalize(activeFilter);
  return filter !== "" && filter === normalize(setting.setting);
}

export default class SiteSettingStore extends Service {
  byName = trackedMap();

  register(settings) {
    settings.forEach((setting) => {
      this.byName.set(setting.setting, setting);

      if (setting.depends_behavior === "hidden" && setting.depends_on?.length) {
        setting.revealed = setting.depends_on.every((name) => {
          const parent = this.byName.get(name);
          return parent ? isSettingValueTrue(parent.value) : true;
        });
      }
    });
  }

  get(name) {
    return this.byName.get(name);
  }

  reveal(name) {
    this.byName.forEach((setting) => {
      if (
        setting.depends_behavior === "hidden" &&
        setting.depends_on?.includes(name)
      ) {
        setting.revealed = true;
      }
    });
  }
}
