import RawHtml from "discourse/widgets/raw-html";
import { iconHTML } from "discourse-common/lib/icon-library";
import { h } from "@discourse/virtual-dom";
import QuickAccessPanel from "discourse/widgets/quick-access-panel";
import { createWidget, createWidgetFrom } from "discourse/widgets/widget";
import { postUrl } from "discourse/lib/utilities";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

const ICON = "notification.private_message";

function toItem(message) {
  const lastReadPostNumber = message.last_read_post_number || 0;
  const nextUnreadPostNumber = Math.min(
    lastReadPostNumber + 1,
    message.highest_post_number
  );

  return {
    escapedContent: message.fancy_title,
    href: postUrl(message.slug, message.id, nextUnreadPostNumber),
    icon: ICON,
    read: message.last_read_post_number >= message.highest_post_number,
    username: message.last_poster_username,
  };
}

createWidget("no-quick-access-messages", {
  html() {
    return h("div.empty-state", [
      h("span.empty-state-title", I18n.t("user.no_messages_title")),
      h(
        "div.empty-state-body",
        new RawHtml({
          html:
            "<p>" +
            htmlSafe(
              I18n.t("user.no_messages_body", {
                aboutUrl: getURL("/about"),
                icon: iconHTML("envelope"),
              })
            ) +
            "</p>",
        })
      ),
    ]);
  },
});

createWidgetFrom(QuickAccessPanel, "quick-access-messages", {
  buildKey: () => "quick-access-messages",
  emptyStateWidget: "no-quick-access-messages",

  showAllHref() {
    return `${this.attrs.path}/messages`;
  },

  findNewItems() {
    return this.store
      .findFiltered("topicList", {
        filter: `topics/private-messages/${this.currentUser.username_lower}`,
      })
      .then(({ topic_list }) => {
        return topic_list.topics.map(toItem);
      });
  },

  itemHtml(message) {
    return this.attach("quick-access-item", message);
  },
});
