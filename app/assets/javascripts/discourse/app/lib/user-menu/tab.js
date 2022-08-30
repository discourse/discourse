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
   * @returns {string} Dasherized version of the component name that should be rendered in the panel area when the tab is active.
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

  getUnreadCountForType(type) {
    const key = `grouped_unread_high_priority_notifications.${this.site.notification_types[type]}`;
    // we're retrieving the value with get() so that Ember tracks the property
    // and re-renders the UI when it changes.
    // we can stop using `get()` when the User model is refactored into native
    // class with @tracked properties.
    return this.currentUser.get(key) || 0;
  }
}

export const CUSTOM_TABS_CLASSES = [];

export function registerUserMenuTab(func) {
  CUSTOM_TABS_CLASSES.push(func(UserMenuTab));
}

export function resetUserMenuTabs() {
  CUSTOM_TABS_CLASSES.length = 0;
}
