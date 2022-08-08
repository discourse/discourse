import RestModel from "discourse/models/rest";
import { tracked } from "@glimmer/tracking";

export default class UserMenuReviewable extends RestModel {
  @tracked pending;
}
