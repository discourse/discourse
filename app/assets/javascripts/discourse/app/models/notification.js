import RestModel from "discourse/models/rest";
import { tracked } from "@glimmer/tracking";

const DEFAULT_ITEM = "user-menu/notification-item";
const _componentForType = {};

export default class Notification extends RestModel {
  @tracked read;

  get userMenuComponent() {
    const component =
      _componentForType[this.site.notificationLookup[this.notification_type]];
    return component || DEFAULT_ITEM;
  }
}
