import { computed } from "@ember/object";

export default class AdType {
  constructor(id, key) {
    this.id = id;
    this.key = key;
  }

  @computed
  get name() {
    const names = {
      house: "House Ad",
      adsense: "Google AdSense",
      dfp: "Google DFP",
      amazon: "Amazon",
      carbon: "Carbon",
      adbutler: "AdButler",
    };
    return names[this.key] || this.key;
  }
}
