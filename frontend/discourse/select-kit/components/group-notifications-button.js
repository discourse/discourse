import { classNames } from "@ember-decorators/component";
import NotificationOptionsComponent from "discourse/select-kit/components/notifications-button";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";

@classNames("group-notifications-button")
@selectKitOptions({
  i18nPrefix: "groups.notifications",
})
@pluginApiIdentifiers("group-notifications-button")
export default class GroupNotificationsButton extends NotificationOptionsComponent {}
