import { tracked } from "@glimmer/tracking";
import { dependentKeyCompat } from "@ember/object/compat";
import { isEmpty } from "@ember/utils";
import { deepEqual } from "discourse/lib/object";
import { trackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";

export default class Archetype extends RestModel {
  @tracked id;
  @tracked site;
  @trackedArray options;

  @dependentKeyCompat
  get isDefault() {
    return deepEqual(this.id, this.site?.default_archetype);
  }

  @dependentKeyCompat
  get hasOptions() {
    return !isEmpty(this.options);
  }

  @dependentKeyCompat
  get notDefault() {
    return !this.isDefault;
  }
}
