import { computed } from "@ember/object";
import I18n from "I18n";

export default class TrustLevel {
  constructor(id, key) {
    this.id = id;
    this._key = key;
  }

  @computed
  get name() {
    return I18n.t(`trust_levels.names.${this._key}`);
  }

  @computed
  get detailedName() {
    return I18n.t("trust_levels.detailed_name", {
      level: this.id,
      name: this.name,
    });
  }
}
