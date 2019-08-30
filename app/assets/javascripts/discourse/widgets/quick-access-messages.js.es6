import DiscourseURL from "discourse/lib/url";
import QuickAccessPanel from "discourse/widgets/quick-access-panel";
import { createWidgetFrom } from "discourse/widgets/widget";

let staleItems = [];

/**
 * Transforms the raw topic list payload item, so that the
 * `DefaultNotificationItem` can be reused.
 */
function toNotificationItem(message) {
  const lastReadPostNumber = message.last_read_post_number || 0;
  const nextUnreadPostNumber = Math.min(
    lastReadPostNumber + 1,
    message.highest_post_number
  );

  return Ember.Object.create({
    id: null,
    notification_type: Discourse.Site.currentProp("notification_types")[
      "private_message"
    ],
    read: message.last_read_post_number >= message.highest_post_number,
    topic_id: message.id,
    post_number: nextUnreadPostNumber,
    slug: message.slug,
    fancy_title: message.fancy_title,
    data: {
      display_username: message.last_poster_username,
      topic_title: message.title
    }
  });
}

createWidgetFrom(QuickAccessPanel, "quick-access-messages", {
  buildKey: () => "quick-access-messages",
  emptyStatePlaceholderItemKey: "choose_topic.none_found",

  hasMore() {
    // Always show the button to the messages page for composing, archiving,
    // etc.
    return true;
  },

  showAll() {
    DiscourseURL.routeTo(`${this.attrs.path}/messages`);
  },

  findStaleItems() {
    return staleItems || [];
  },

  findNewItems() {
    return this.store
      .findFiltered("topicList", {
        filter: `topics/private-messages/${this.currentUser.username_lower}`
      })
      .then(({ topic_list }) => {
        return (staleItems = topic_list.topics
          .map(toNotificationItem)
          .slice(0, this.estimateItemLimit()));
      });
  },

  itemHtml(message) {
    return this.attach("default-notification-item", message);
  }
});
