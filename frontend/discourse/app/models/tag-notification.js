import RestCompatModel from "discourse/data/rest-compat";
import { TagNotificationSchema } from "discourse/data/schemas/tag-notification";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";

export default class TagNotification extends RestCompatModel {
  static type = "tag-notification";
  primaryKey = "name";
}

defineFieldForwarders(TagNotification, TagNotificationSchema);
