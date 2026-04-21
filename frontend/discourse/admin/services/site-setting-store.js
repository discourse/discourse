import { trackedMap } from "@ember/reactive/collections";
import Service from "@ember/service";

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
    settings.forEach((s) => this.byName.set(s.setting, s));

    settings.forEach((s) => {
      if (s.depends_behavior === "hidden" && s.depends_on?.length) {
        s.revealed = s.depends_on.every((name) => {
          const parent = this.byName.get(name);
          return parent ? String(parent.value) === "true" : true;
        });
      }
    });
  }

  get(name) {
    return this.byName.get(name);
  }

  reveal(name) {
    this.byName.forEach((s) => {
      if (s.depends_behavior === "hidden" && s.depends_on?.includes(name)) {
        s.revealed = true;
      }
    });
  }
}
