import { classNames } from "@ember-decorators/component";
import NotificationsButtonComponent from "select-kit/components/notifications-button";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("tag-notifications-button")
@selectKitOptions({
  showFullTitle: false,
  i18nPrefix: "tagging.notifications",
})
@pluginApiIdentifiers("tag-notifications-button")
export default class TagNotificationsButton extends NotificationsButtonComponent {}
