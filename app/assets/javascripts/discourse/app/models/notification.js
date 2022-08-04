import RestModel from "discourse/models/rest";
import { tracked } from "@glimmer/tracking";

const DEFAULT_COMPONENT = "user-menu/notification-item";

const COMPONENT_FOR_TYPE = {
  bookmark_reminder: "user-menu/bookmark-reminder-notification-item",
  custom: "user-menu/custom-notification-item",
  granted_badge: "user-menu/granted-badge-notification-item",
  group_mentioned: "user-menu/group-mentioned-notification-item",
  group_message_summary: "user-menu/group-message-summary-notification-item",
  invitee_accepted: "user-menu/invitee-accepted-notification-item",
  liked: "user-menu/liked-notification-item",
  liked_consolidated: "user-menu/liked-consolidated-notification-item",
  membership_request_accepted:
    "user-menu/membership-request-accepted-notification-item",
  membership_request_consolidated:
    "user-menu/membership-request-consolidated-notification-item",
  moved_post: "user-menu/moved-post-notification-item",
  watching_first_post: "user-menu/watching-first-post-notification-item",
};

let _customComponentForType = {};

export function registerUserMenuComponentForNotificationType(
  notificationType,
  component
) {
  _customComponentForType[notificationType] = component;
}

export function resetUserMenuCustomComponents() {
  _customComponentForType = {};
}

export default class Notification extends RestModel {
  @tracked read;

  get userMenuComponent() {
    const type = this.site.notificationLookup[this.notification_type];
    const component = _customComponentForType[type] || COMPONENT_FOR_TYPE[type];
    return component || DEFAULT_COMPONENT;
  }
}
