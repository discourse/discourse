import UserMenuBaseItem from "discourse/lib/user-menu/base-item";
import UserMenuBookmarkItem from "discourse/lib/user-menu/bookmark-item";
import UserMenuMessageItem from "discourse/lib/user-menu/message-item";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import UserMenuReviewableItem from "discourse/lib/user-menu/reviewable-item";

const CORE_RENDERERS = {
  notification: UserMenuNotificationItem,
  bookmark: UserMenuBookmarkItem,
  message: UserMenuMessageItem,
  reviewable: UserMenuReviewableItem,
};

let PLUGIN_RENDERERS = {};
let PLUGIN_OVERRIDES = {};

export function findUserMenuItemRenderer(type) {
  return (
    PLUGIN_OVERRIDES[type] || CORE_RENDERERS[type] || PLUGIN_RENDERERS[type]
  );
}

export function registerUserMenuItemRenderer(type, func) {
  PLUGIN_RENDERERS[type] = func(UserMenuBaseItem);
}

export function replaceUserMenuItemRenderer(type, func) {
  const overridden = findUserMenuItemRenderer(type);
  if (overridden) {
    PLUGIN_OVERRIDES[type] = func(overridden);
  } else {
    // TODO: console log some warning/error with console prefix
  }
}

export function resetUserMenuItemRenderers() {
  PLUGIN_RENDERERS = {};
  PLUGIN_OVERRIDES = {};
}
