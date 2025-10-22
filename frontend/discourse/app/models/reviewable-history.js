import { equal } from "@ember/object/computed";
import RestModel from "discourse/models/rest";

export const CREATED = 0;
export const TRANSITIONED_TO = 1;
export const EDITED = 2;

export default class ReviewableHistory extends RestModel {
  @equal("reviewable_history_type", CREATED) created;
}
