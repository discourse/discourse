import { isEmpty } from "@ember/utils";
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
        return Discourse.getURL(
          "/badges/" + badgeId + "/" + badgeSlug + username
        );
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
      const description = this.description(data);

      return I18n.t(`notifications.${notificationName}`, {
        description,
        username
      });
    },

    icon(notificationName) {
      return iconNode(`notification.${notificationName}`);
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
      if (document && document.cookie) {
        let path = Discourse.BaseUri || "/";
        document.cookie = `cn=${id}; path=${path}; expires=Fri, 31 Dec 9999 23:59:59 GMT`;
      }
      if (wantsNewWindow(e)) {
        return;
      }
      e.preventDefault();

      this.sendWidgetEvent("linkClicked");
      DiscourseURL.routeTo(this.url(this.attrs.data), {
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
  }
);
