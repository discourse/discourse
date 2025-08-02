import { i18n } from "discourse-i18n";

/**
 * abstract class representing a tab in the user menu
 */
export default class UserMenuTab {
  constructor(currentUser, siteSettings, site) {
    this.currentUser = currentUser;
    this.siteSettings = siteSettings;
    this.site = site;
  }

  /**
   * @returns {boolean} Controls whether the tab should be rendered or not.
   */
  get shouldDisplay() {
    return true;
  }

  /**
   * @returns {number} Controls the blue badge (aka bubble) count that's rendered on top of the tab. If count is zero, no badge is shown.
   */
  get count() {
    return 0;
  }

  /**
   * @returns {string} title attribute for the tab element in the DOM
   */
  get title() {
    const id = this.id.replaceAll(/-/g, "_");
    const count = this.count;
    let key;
    if (this.count) {
      key = `user_menu.tabs.${id}_with_unread`;
    } else {
      key = `user_menu.tabs.${id}`;
    }

    return i18n(key, { count });
  }

  /**
   * @returns {Component} Component class that should be rendered in the panel area when the tab is active.
   */
  get panelComponent() {
    throw new Error("not implemented");
  }

  /**
   * @returns {string} ID for the tab. Must be unique across all visible tabs.
   */
  get id() {
    throw new Error("not implemented");
  }

  /**
   * @returns {string} Icon for the tab.
   */
  get icon() {
    throw new Error("not implemented");
  }

  /**
   * @returns {Array} Notification types displayed in tab. Those notifications will be removed from "other" tab.
   */
  get notificationTypes() {}

  getUnreadCountForType(type) {
    const key = `grouped_unread_notifications.${this.site.notification_types[type]}`;
    // we're retrieving the value with get() so that Ember tracks the property
    // and re-renders the UI when it changes.
    // we can stop using `get()` when the User model is refactored into native
    // class with @tracked properties.

    // TODO: remove old key fallback after plugins PRs are merged
    // https://github.com/discourse/discourse-chat/pull/1208
    // https://github.com/discourse/discourse-assign/pull/373
    const oldKey = `grouped_unread_high_priority_notifications.${this.site.notification_types[type]}`;

    return this.currentUser.get(key) || this.currentUser.get(oldKey) || 0;
  }
}

export const CUSTOM_TABS_CLASSES = [];

export function registerUserMenuTab(func) {
  CUSTOM_TABS_CLASSES.push(func(UserMenuTab));
}

export function resetUserMenuTabs() {
  CUSTOM_TABS_CLASSES.length = 0;
}
