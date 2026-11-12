import RestCompatModel from "discourse/data/rest-compat";
import { TagNotificationSchema } from "discourse/data/schemas/tag-notification";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";

/** The tag_notification hash returned by the notifications endpoint. */
export interface TagNotificationFields {
  id: number;
  name: string;
  notification_level: number;
}

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface TagNotification extends TagNotificationFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class TagNotification extends RestCompatModel {
  static override type = "tag-notification";

  declare id: number;
  override primaryKey = "name";
}

defineFieldForwarders(TagNotification, TagNotificationSchema);
