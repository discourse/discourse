import RestModel from "discourse/models/rest";
import { tracked } from "@glimmer/tracking";
import { applyModelTransformations } from "discourse/lib/model-transformers";

export default class Notification extends RestModel {
  static async applyTransformations(notifications) {
    await applyModelTransformations("notification", notifications);
  }

  static async initializeNotifications(rawList) {
    const notifications = rawList.map((n) => this.create(n));
    await this.applyTransformations(notifications);
    return notifications;
  }

  @tracked read;
}
