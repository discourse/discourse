import { autoTrackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";

export default class Embedding extends RestModel {
  @autoTrackedArray embeddable_hosts;
}
