import { setTransientHeader } from "discourse/lib/ajax";
import { getRenderDirector } from "discourse/lib/notification-item";
import getURL from "discourse-common/lib/get-url";
import cookie from "discourse/lib/cookie";
import UserMenuItemsListBaseItem from "discourse/components/user-menu/items-list-base-item";

export default class UserMenuNotificationItem extends UserMenuItemsListBaseItem {
  constructor({ site, currentUser, siteSettings, notification }) {
    super(...arguments);
    this.site = site;
    this.currentUser = currentUser;
    this.siteSettings = siteSettings;
    this.notification = notification;

    this.renderDirector = getRenderDirector(
      this.#notificationName,
      this.notification,
      this.currentUser,
      this.siteSettings,
      this.site
    );
  }

  get classNames() {
    const classes = [];

    if (this.notification.read) {
      classes.push("read");
    }

    if (this.#notificationName) {
      classes.push(this.#notificationName.replace(/_/g, "-"));
    }

    if (this.notification.is_warning) {
      classes.push("is-warning");
    }

    const extras = this.renderDirector.classNames;

    if (extras?.length) {
      classes.push(...extras);
    }

    return classes.join(" ");
  }

  get linkHref() {
    return this.renderDirector.linkHref;
  }

  get linkTitle() {
    return this.renderDirector.linkTitle;
  }

  get icon() {
    return this.renderDirector.icon;
  }

  get label() {
    return this.renderDirector.label;
  }

  get labelWrapperClasses() {
    let classes = ["notification-label"];

    if (this.renderDirector.labelWrapperClasses) {
      classes = classes.concat(this.renderDirector.labelWrapperClasses);
    }

    return classes.join(" ");
  }

  get description() {
    return this.renderDirector.description;
  }

  get descriptionWrapperClasses() {
    let classes = ["notification-description"];

    if (this.renderDirector.descriptionWrapperClasses) {
      classes = classes.concat(this.renderDirector.descriptionWrapperClasses);
    }

    return classes.join(" ");
  }

  get #notificationName() {
    return this.site.notificationLookup[this.notification.notification_type];
  }

  onClick() {
    if (!this.notification.read) {
      this.notification.set("read", true);
      setTransientHeader("Discourse-Clear-Notifications", this.notification.id);
      cookie("cn", this.notification.id, { path: getURL("/") });
    }

    this.renderDirector.onClick();
  }
}
