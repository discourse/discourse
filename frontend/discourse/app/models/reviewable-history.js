import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";

export const CREATED = 0;
export const TRANSITIONED_TO = 1;
export const EDITED = 2;

export default class ReviewableHistory extends RestModel {
  @computed("reviewable_history_type")
  get created() {
    return this.reviewable_history_type === CREATED;
  }
}
