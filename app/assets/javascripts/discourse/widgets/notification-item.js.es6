import { wantsNewWindow } from "discourse/lib/intercept-click";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import DiscourseURL from "discourse/lib/url";
import { h } from "virtual-dom";
import { emojiUnescape } from "discourse/lib/text";
import {
  postUrl,
  escapeExpression,
  formatUsername
} from "discourse/lib/utilities";
import { setTransientHeader } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";
import { iconNode } from "discourse-common/lib/icon-library";

const LIKED_TYPE = 5;
const INVITED_TYPE = 8;
const GROUP_SUMMARY_TYPE = 16;
export const LIKED_CONSOLIDATED_TYPE = 19;

createWidget("notification-item", {
  tagName: "li",

  buildClasses(attrs) {
    const classNames = [];
    if (attrs.get("read")) {
      classNames.push("read");
    }
    if (attrs.is_warning) {
      classNames.push("is-warning");
    }
    return classNames;
  },

  url() {
    const attrs = this.attrs;
    const data = attrs.data;

    const badgeId = data.badge_id;
    if (badgeId) {
      let badgeSlug = data.badge_slug;

      if (!badgeSlug) {
        const badgeName = data.badge_name;
        badgeSlug = badgeName.replace(/[^A-Za-z0-9_]+/g, "-").toLowerCase();
      }

      let username = data.username;
      username = username ? "?username=" + username.toLowerCase() : "";
      return Discourse.getURL(
        "/badges/" + badgeId + "/" + badgeSlug + username
      );
    }

    const topicId = attrs.topic_id;

    if (topicId) {
      return postUrl(attrs.slug, topicId, attrs.post_number);
    }

    if (attrs.notification_type === INVITED_TYPE) {
      return userPath(data.display_username);
    }

    if (attrs.notification_type === LIKED_CONSOLIDATED_TYPE) {
      return userPath(
        `${this.attrs.username ||
          this.currentUser
            .username}/notifications/likes-received?acting_username=${
          data.display_username
        }`
      );
    }

    if (data.group_id) {
      return userPath(data.username + "/messages/group/" + data.group_name);
    }
  },

  description() {
    const data = this.attrs.data;
    const badgeName = data.badge_name;
    if (badgeName) {
      return escapeExpression(badgeName);
    }

    if (this.attrs.fancy_title) {
      return this.attrs.fancy_title;
    }

    let title;

    if (this.attrs.notification_type === LIKED_CONSOLIDATED_TYPE) {
      title = I18n.t("notifications.liked_consolidated_description", {
        count: parseInt(data.count)
      });
    } else {
      title = data.topic_title;
    }

    return Ember.isEmpty(title) ? "" : escapeExpression(title);
  },

  text(notificationType, notName) {
    const { attrs } = this;
    const data = attrs.data;
    const scope =
      notName === "custom" ? data.message : `notifications.${notName}`;

    if (notificationType === GROUP_SUMMARY_TYPE) {
      const count = data.inbox_count;
      const group_name = data.group_name;
      return I18n.t(scope, { count, group_name });
    }

    const username = formatUsername(data.display_username);
    const description = this.description();

    if (notificationType === LIKED_TYPE && data.count > 1) {
      const count = data.count - 2;
      const username2 = formatUsername(data.username2);

      if (count === 0) {
        return I18n.t("notifications.liked_2", {
          description,
          username,
          username2
        });
      } else {
        return I18n.t("notifications.liked_many", {
          description,
          username,
          username2,
          count
        });
      }
    }

    return I18n.t(scope, { description, username });
  },

  html(attrs) {
    const notificationType = attrs.notification_type;
    const lookup = this.site.get("notificationLookup");
    const notName = lookup[notificationType];

    let { data } = attrs;
    let infoKey = notName === "custom" ? data.message : notName;
    let text = emojiUnescape(this.text(notificationType, notName));
    let icon = iconNode(`notification.${infoKey}`);

    // We can use a `<p>` tag here once other languages have fixed their HTML
    // translations.
    let html = new RawHtml({ html: `<div>${text}</div>` });

    let contents = [icon, html];

    const href = this.url();
    return href
      ? h("a", { attributes: { href, "data-auto-route": true } }, contents)
      : contents;
  },

  click(e) {
    this.attrs.set("read", true);
    const id = this.attrs.id;
    setTransientHeader("Discourse-Clear-Notifications", id);
    if (document && document.cookie) {
      let path = Discourse.BaseUri || "/";
      document.cookie = `cn=${id}; path=${path}; expires=Fri, 31 Dec 9999 23:59:59 GMT`;
    }
    if (wantsNewWindow(e)) {
      return;
    }
    e.preventDefault();

    this.sendWidgetEvent("linkClicked");
    DiscourseURL.routeTo(this.url(), {
      afterRouteComplete: () => {
        if (!this.attrs.data.revision_number) {
          return;
        }

        this.appEvents.trigger(
          "post:show-revision",
          this.attrs.post_number,
          this.attrs.data.revision_number
        );
      }
    });
  }
});
