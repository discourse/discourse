import NotificationTypeBase from "discourse/lib/notification-types/base";
import { i18n } from "discourse-i18n";

export default class extends NotificationTypeBase {
  /**
   * Names the recipient's topic that was linked, rather than the topic doing
   * the linking, so they can tell which of their own topics this is about.
   *
   * One post can link several of their topics but only produces a single
   * notification. The description is a single clamped line, so listing every
   * title runs past the end and cuts mid-word; the first title plus a count
   * of the rest stays readable and still says how many there were.
   */
  get description() {
    const topics = this.notification.data.linked_topics;
    if (!topics?.length) {
      return super.description;
    }

    const total = this.notification.data.linked_topics_count ?? topics.length;
    const remaining = total - 1;

    if (remaining > 0) {
      return i18n("notifications.linked_topics_with_others", {
        topic: topics[0].title,
        count: remaining,
      });
    }

    return topics[0].title;
  }
}
