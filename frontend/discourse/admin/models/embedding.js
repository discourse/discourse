import { trackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";

export default class Embedding extends RestModel {
  @trackedArray embeddable_hosts;
}
