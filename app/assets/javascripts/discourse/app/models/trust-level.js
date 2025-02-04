import { computed } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class TrustLevel {
  constructor(id, key) {
    this.id = id;
    this._key = key;
  }

  @computed
  get name() {
    return i18n(`trust_levels.names.${this._key}`);
  }

  @computed
  get detailedName() {
    return i18n("trust_levels.detailed_name", {
      level: this.id,
      name: this.name,
    });
  }
}
