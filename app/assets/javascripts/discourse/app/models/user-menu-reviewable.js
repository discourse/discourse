import { tracked } from "@glimmer/tracking";
import RestModel from "discourse/models/rest";

export default class UserMenuReviewable extends RestModel {
  @tracked pending;
}
