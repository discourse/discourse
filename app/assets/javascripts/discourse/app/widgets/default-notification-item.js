import DiscourseURL, { userPath } from "discourse/lib/url";
import { ajax, setTransientHeader } from "discourse/lib/ajax";
import {
  escapeExpression,
  formatUsername,
  postUrl,
} from "discourse/lib/utilities";
import I18n from "I18n";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import { emojiUnescape } from "discourse/lib/text";
import getURL from "discourse-common/lib/get-url";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import { isEmpty } from "@ember/utils";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import cookie from "discourse/lib/cookie";

export const DefaultNotificationItem = createWidget(
  "default-notification-item",
  {
    tagName: "li",

    buildClasses(attrs) {
      const classNames = [];
      if (attrs.get("read")) {
        classNames.push("read");
      }
      if (attrs.is_warning) {
        classNames.push("is-warning");
      }
      const notificationType = attrs.notification_type;
      const lookup = this.site.get("notificationLookup");
      const notificationName = lookup[notificationType];
      if (notificationName) {
        classNames.push(notificationName.replace(/_/g, "-"));
      }
      return classNames;
    },

    url(data) {
      const attrs = this.attrs;

      const badgeId = data.badge_id;
      if (badgeId) {
        let badgeSlug = data.badge_slug;

        if (!badgeSlug) {
          const badgeName = data.badge_name;
          badgeSlug = badgeName.replace(/[^A-Za-z0-9_]+/g, "-").toLowerCase();
        }

        let username = data.username;
        username = username ? "?username=" + username.toLowerCase() : "";
        return getURL("/badges/" + badgeId + "/" + badgeSlug + username);
      }

      const topicId = attrs.topic_id;

      if (topicId) {
        return postUrl(attrs.slug, topicId, attrs.post_number);
      }

      if (data.group_id) {
        return userPath(data.username + "/messages/group/" + data.group_name);
      }
    },

    description(data) {
      const badgeName = data.badge_name;
      if (badgeName) {
        return escapeExpression(badgeName);
      }

      const groupName = data.group_name;

      if (groupName) {
        if (this.attrs.fancy_title) {
          if (this.attrs.topic_id) {
            return `<span class="mention-group notify">@${groupName}</span><span data-topic-id="${this.attrs.topic_id}"> ${this.attrs.fancy_title}</span>`;
          }
          return `<span class="mention-group notify">@${groupName}</span> ${this.attrs.fancy_title}`;
        }
      }

      if (this.attrs.fancy_title) {
        if (this.attrs.topic_id) {
          return `<span data-topic-id="${this.attrs.topic_id}">${this.attrs.fancy_title}</span>`;
        }
        return this.attrs.fancy_title;
      }

      const description = data.topic_title;

      return isEmpty(description) ? "" : escapeExpression(description);
    },

    text(notificationName, data) {
      const username = formatUsername(data.display_username);
      const description = this.description(data, notificationName);

      return I18n.t(`notifications.${notificationName}`, {
        description,
        username,
      });
    },

    icon(notificationName) {
      return iconNode(`notification.${notificationName}`);
    },

    _addA11yAttrsTo(icon, notificationName) {
      icon.properties.attributes["aria-label"] = I18n.t(
        `notifications.titles.${notificationName}`
      );
      icon.properties.attributes["aria-hidden"] = false;
      icon.properties.attributes["role"] = "img";
      return icon;
    },

    notificationTitle(notificationName) {
      if (notificationName) {
        return I18n.t(`notifications.titles.${notificationName}`);
      } else {
        return "";
      }
    },

    html(attrs) {
      const notificationType = attrs.notification_type;
      const lookup = this.site.get("notificationLookup");
      const notificationName = lookup[notificationType];

      let { data } = attrs;
      let text = emojiUnescape(this.text(notificationName, data));
      let icon = this.icon(notificationName, data);
      this._addA11yAttrsTo(icon, notificationName);

      const title = this.notificationTitle(notificationName, data);

      // We can use a `<p>` tag here once other languages have fixed their HTML
      // translations.
      let html = new RawHtml({ html: `<div>${text}</div>` });

      let contents = [icon, html];

      const href = this.url(data);
      return href
        ? h(
            "a",
            { attributes: { href, title, "data-auto-route": true } },
            contents
          )
        : contents;
    },

    click(e) {
      this.attrs.set("read", true);
      const id = this.attrs.id;
      setTransientHeader("Discourse-Clear-Notifications", id);
      cookie("cn", id, { path: getURL("/") });

      if (wantsNewWindow(e)) {
        return;
      }
      e.preventDefault();

      this.sendWidgetEvent("linkClicked");
      if (this.attrs.data.revision_number) {
        this.appEvents.trigger("edit-notification:clicked", {
          topicId: this.attrs.topic_id,
          postNumber: this.attrs.post_number,
          revisionNumber: this.attrs.data.revision_number,
        });
      }
      DiscourseURL.routeTo(this.url(this.attrs.data));
    },

    mouseUp(event) {
      // dismiss notification on middle click
      if (event.which === 2 && !this.attrs.read) {
        this.attrs.set("read", true);
        ajax("/notifications/mark-read", {
          method: "PUT",
          data: { id: this.attrs.id },
        });
      }
    },
  }
);
