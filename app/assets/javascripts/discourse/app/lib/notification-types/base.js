import { htmlSafe } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import { formatUsername, postUrl } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class NotificationTypeBase {
  constructor({ notification, currentUser, siteSettings, site }) {
    this.notification = notification;
    this.currentUser = currentUser;
    this.siteSettings = siteSettings;
    this.site = site;
  }

  /**
   * @returns {string[]} An array of addtional classes that should be added to the <li> element of the notification item.
   */
  get classNames() {
    const classes = ["notification"];
    if (this.notification.read) {
      classes.push("read");
    } else {
      classes.push("unread");
    }
    if (this.notificationName) {
      classes.push(this.notificationName.replace(/_/g, "-"));
    }
    if (this.notification.is_warning) {
      classes.push("is-warning");
    }
    return classes;
  }

  /**
   * @returns {string} A href/path that the notification item should link to.
   */
  get linkHref() {
    if (this.topicId) {
      return postUrl(
        this.notification.slug,
        this.topicId,
        this.notification.post_number
      );
    }
    if (this.notification.data.group_id) {
      return userPath(
        `${this.notification.data.username}/messages/${this.notification.data.group_name}`
      );
    }
  }

  /**
   * @returns {string} A title for the notification item. It shows up when the user hovers over the notification item.
   */
  get linkTitle() {
    if (this.notificationName) {
      return i18n(`notifications.titles.${this.notificationName}`);
    } else {
      // notifications with unknown types, e.g. notifications that come from a
      // plugin that's no longer installed
      return "";
    }
  }

  /**
   * @returns {string} An icon for the notification item.
   */
  get icon() {
    return `notification.${this.notificationName}`;
  }

  /**
   * @returns {string} The label is the first part of the text content displayed in the notification. For example, in a like notification, the username of the user who liked the post is the label. If a falsey value is returned, the label is omitted.
   */
  get label() {
    return this.username;
  }

  /**
   * @returns {string} The description is the second part of the text content displayed in the notification. For example, in a like notification, the topic title is the description. If a falsey value is returned, the description is omitted.
   */
  get description() {
    const description = emojiUnescape(this.notification.fancy_title);
    if (description) {
      return htmlSafe(description);
    } else {
      return this.notification.data.topic_title;
    }
  }

  /**
   * @returns {string[]} Include additional classes to the label.
   */
  get labelClasses() {
    return [];
  }

  /**
   * @returns {string[]} Include additional classes to the description.
   */
  get descriptionClasses() {
    return [];
  }

  get topicId() {
    return this.notification.topic_id;
  }

  get username() {
    return formatUsername(this.notification.data.display_username);
  }

  get notificationName() {
    return this.site.notificationLookup[this.notification.notification_type];
  }
}
