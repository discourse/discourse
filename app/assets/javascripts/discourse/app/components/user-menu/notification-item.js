import UserMenuItem from "discourse/components/user-menu/menu-item";
import { setTransientHeader } from "discourse/lib/ajax";
import { action } from "@ember/object";
import { getRenderDirector } from "discourse/lib/notification-item";
import getURL from "discourse-common/lib/get-url";
import cookie from "discourse/lib/cookie";
import { inject as service } from "@ember/service";

export default class UserMenuNotificationItem extends UserMenuItem {
  @service currentUser;
  @service siteSettings;
  @service site;

  constructor() {
    super(...arguments);
    this.renderDirector = getRenderDirector(
      this.#notificationName,
      this.notification,
      this.currentUser,
      this.siteSettings,
      this.site
    );
  }

  get className() {
    const classes = ["notification"];
    if (this.notification.read) {
      classes.push("read");
    } else {
      classes.push("unread");
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

  get labelClass() {
    return this.renderDirector.labelClasses?.join(" ") || "";
  }

  get description() {
    return this.renderDirector.description;
  }

  get descriptionClass() {
    return this.renderDirector.descriptionClasses?.join(" ") || "";
  }

  get topicId() {
    return this.notification.topic_id;
  }

  get notification() {
    return this.args.item;
  }

  get #notificationName() {
    return this.site.notificationLookup[this.notification.notification_type];
  }

  @action
  onClick() {
    if (!this.notification.read) {
      this.notification.set("read", true);
      setTransientHeader("Discourse-Clear-Notifications", this.notification.id);
      cookie("cn", this.notification.id, { path: getURL("/") });
    }
    this.renderDirector.onClick();
  }
}
