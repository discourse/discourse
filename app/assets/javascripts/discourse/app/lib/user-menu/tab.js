export default class UserMenuTab {
  constructor(currentUser, siteSettings, site) {
    this.currentUser = currentUser;
    this.siteSettings = siteSettings;
    this.site = site;
  }

  get shouldDisplay() {
    return true;
  }

  get count() {
    return 0;
  }

  get panelComponent() {
    throw new Error("not implemented");
  }

  get id() {
    throw new Error("not implemented");
  }

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
