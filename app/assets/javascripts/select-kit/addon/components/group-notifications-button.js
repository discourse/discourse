import { classNames } from "@ember-decorators/component";
import NotificationOptionsComponent from "select-kit/components/notifications-button";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("group-notifications-button")
@selectKitOptions({
  i18nPrefix: "groups.notifications",
})
@pluginApiIdentifiers("group-notifications-button")
export default class GroupNotificationsButton extends NotificationOptionsComponent {}
