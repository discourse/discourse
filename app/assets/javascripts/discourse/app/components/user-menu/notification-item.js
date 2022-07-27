import GlimmerComponent from "discourse/components/glimmer";
import { formatUsername, postUrl } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";
import { setTransientHeader } from "discourse/lib/ajax";
import { action } from "@ember/object";
import { emojiUnescape } from "discourse/lib/text";
import { htmlSafe } from "@ember/template";
import getURL from "discourse-common/lib/get-url";
import cookie from "discourse/lib/cookie";
import I18n from "I18n";

export default class UserMenuNotificationItem extends GlimmerComponent {
  get className() {
    const classes = [];
    if (this.notification.read) {
      classes.push("read");
    }
    if (this.notificationName) {
      classes.push(this.notificationName.replace(/_/g, "-"));
    }
    if (this.notification.is_warning) {
      classes.push("is-warning");
    }
    return classes.join(" ");
  }

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

  get linkTitle() {
    if (this.notificationName) {
      return I18n.t(`notifications.titles.${this.notificationName}`);
    } else {
      return "";
    }
  }

  get icon() {
    return `notification.${this.notificationName}`;
  }

  get label() {
    return this.username;
  }

  get wrapLabel() {
    return true;
  }

  get labelWrapperClasses() {}

  get username() {
    return formatUsername(this.notification.data.display_username);
  }

  get description() {
    const description =
      emojiUnescape(this.notification.fancy_title) ||
      this.notification.data.topic_title;

    if (this.descriptionHtmlSafe) {
      return htmlSafe(description);
    } else {
      return description;
    }
  }

  get descriptionElementClasses() {}

  get descriptionHtmlSafe() {
    return !!this.notification.fancy_title;
  }

  // the following props are helper props -- they're never referenced directly in the hbs template
  get notification() {
    return this.args.item;
  }

  get topicId() {
    return this.notification.topic_id;
  }

  get notificationName() {
    return this.site.notificationLookup[this.notification.notification_type];
  }

  @action
  onClick() {
    if (!this.notification.read) {
      this.notification.set("read", true);
      setTransientHeader("Discourse-Clear-Notifications", this.notification.id);
      cookie("cn", this.notification.id, { path: getURL("/") });
    }
  }
}
