import RestModel from "discourse/models/rest";
import { tracked } from "@glimmer/tracking";

export default class Notification extends RestModel {
  @tracked read;
}
