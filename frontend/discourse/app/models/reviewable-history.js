import { tracked } from "@glimmer/tracking";
import { dependentKeyCompat } from "@ember/object/compat";
import RestModel from "discourse/models/rest";

export const CREATED = 0;
export const TRANSITIONED_TO = 1;
export const EDITED = 2;

export default class ReviewableHistory extends RestModel {
  @tracked reviewable_history_type;

  @dependentKeyCompat
  get created() {
    return this.reviewable_history_type === CREATED;
  }
}
