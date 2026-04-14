import { computed } from "@ember/object";
import { deepEqual } from "discourse/lib/object";
import RestModel from "discourse/models/rest";

export default class Archetype extends RestModel {
  @computed("options.length")
  get hasOptions() {
    return this.options?.length > 0;
  }

  @computed("id", "site.default_archetype")
  get isDefault() {
    return deepEqual(this.id, this.site?.default_archetype);
  }

  @computed("isDefault")
  get notDefault() {
    return !this.isDefault;
  }
}
