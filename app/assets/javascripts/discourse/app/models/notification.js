import RestModel from "discourse/models/rest";
import { tracked } from "@glimmer/tracking";
import { applyModelTransformations } from "discourse/lib/model-transformers";

export default class Notification extends RestModel {
  static async applyTransformations(notifications) {
    await applyModelTransformations("notification", notifications);
  }

  @tracked read;
}
