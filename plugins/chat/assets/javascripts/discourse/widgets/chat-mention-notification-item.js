import I18n from "I18n";
import RawHtml from "discourse/widgets/raw-html";
import { createWidgetFrom } from "discourse/widgets/widget";
import { DefaultNotificationItem } from "discourse/widgets/default-notification-item";
import { h } from "virtual-dom";
import { formatUsername } from "discourse/lib/utilities";
import { iconNode } from "discourse-common/lib/icon-library";
import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";

const chatNotificationItem = {
  services: ["chat", "router"],

  text(notificationName, data) {
    const username = formatUsername(data.mentioned_by_username);
    const identifier = data.identifier ? `@${data.identifier}` : null;
    const i18nPrefix = data.is_direct_message_channel
      ? "notifications.popup.direct_message_chat_mention"
      : "notifications.popup.chat_mention";
    const i18nSuffix = identifier ? "other_html" : "direct_html";

    return I18n.t(`${i18nPrefix}.${i18nSuffix}`, {
      username,
      identifier,
      channel: data.chat_channel_title,
    });
  },

  html(attrs) {
    const notificationType = attrs.notification_type;
    const lookup = this.site.get("notificationLookup");
    const notificationName = lookup[notificationType];
    const { data } = attrs;
    const title = this.notificationTitle(notificationName, data);
    const text = this.text(notificationName, data);
    const html = new RawHtml({ html: `<div>${text}</div>` });
    const contents = [iconNode("comment"), html];
    const href = this.url(data);

    return h(
      "a",
      { attributes: { title, href, "data-auto-route": true } },
      contents
    );
  },

  url(data) {
    const slug = slugifyChannel({
      title: data.chat_channel_title,
      slug: data.chat_channel_slug,
    });
    return `/chat/c/${slug || "-"}/${data.chat_channel_id}/${
      data.chat_message_id
    }`;
  },
};

createWidgetFrom(
  DefaultNotificationItem,
  "chat-mention-notification-item",
  chatNotificationItem
);
createWidgetFrom(
  DefaultNotificationItem,
  "chat-group-mention-notification-item",
  chatNotificationItem
);
