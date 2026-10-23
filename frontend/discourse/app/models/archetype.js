import RestCompatModel from "discourse/data/rest-compat";
import { ArchetypeSchema } from "discourse/data/schemas/archetype";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import { deepEqual } from "discourse/lib/object";

export default class Archetype extends RestCompatModel {
  static type = "archetype";

  get hasOptions() {
    return this.options?.length > 0;
  }

  get isDefault() {
    return deepEqual(this.id, this.site?.default_archetype);
  }

  get notDefault() {
    return !this.isDefault;
  }
}

defineFieldForwarders(Archetype, ArchetypeSchema);
