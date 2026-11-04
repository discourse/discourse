import { computed } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class TrustLevel {
  declare id: number;
  declare _key: string;

  constructor(id: number, key: string) {
    this.id = id;
    this._key = key;
  }

  @computed
  get name(): string {
    return i18n(`trust_levels.names.${this._key}`);
  }

  @computed
  get detailedName(): string {
    return i18n("trust_levels.detailed_name", {
      level: this.id,
      name: this.name,
    });
  }
}
