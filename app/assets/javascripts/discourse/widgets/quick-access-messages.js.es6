import QuickAccessPanel from "discourse/widgets/quick-access-panel";
import { createWidgetFrom } from "discourse/widgets/widget";
import { postUrl } from "discourse/lib/utilities";

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
    username: message.last_poster_username
  };
}

createWidgetFrom(QuickAccessPanel, "quick-access-messages", {
  buildKey: () => "quick-access-messages",
  emptyStatePlaceholderItemKey: "choose_topic.none_found",

  hasMore() {
    // Always show the button to the messages page for composing, archiving,
    // etc.
    return true;
  },

  showAllHref() {
    return `${this.attrs.path}/messages`;
  },

  findNewItems() {
    return this.store
      .findFiltered("topicList", {
        filter: `topics/private-messages/${this.currentUser.username_lower}`
      })
      .then(({ topic_list }) => {
        return topic_list.topics.map(toItem).slice(0, this.estimateItemLimit());
      });
  },

  itemHtml(message) {
    return this.attach("quick-access-item", message);
  }
});
