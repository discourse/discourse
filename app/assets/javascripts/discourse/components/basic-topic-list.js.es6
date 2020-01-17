import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { alias, not } from "@ember/object/computed";
import Component from "@ember/component";

export default Component.extend({
  loadingMore: alias("topicList.loadingMore"),
  loading: not("loaded"),

  @discourseComputed("topicList.loaded")
  loaded() {
    var topicList = this.topicList;
    if (topicList) {
      return topicList.get("loaded");
    } else {
      return true;
    }
  },

  @observes("topicList.[]")
  _topicListChanged: function() {
    this._initFromTopicList(this.topicList);
  },

  _initFromTopicList(topicList) {
    if (topicList !== null) {
      this.set("topics", topicList.get("topics"));
      this.rerender();
    }
  },

  init() {
    this._super(...arguments);
    const topicList = this.topicList;
    if (topicList) {
      this._initFromTopicList(topicList);
    }
  },

  didInsertElement() {
    this._super(...arguments);

    this.topics.forEach(topic => {
      const includeUnreadIndicator =
        typeof topic.unread_by_group_member !== "undefined";

      if (includeUnreadIndicator) {
        const unreadIndicatorChannel = `/private-messages/unread-indicator/${topic.id}`;
        this.messageBus.subscribe(unreadIndicatorChannel, data => {
          const nodeClassList = document.querySelector(
            `.indicator-topic-${data.topic_id}`
          ).classList;

          if (data.show_indicator) {
            nodeClassList.remove("read");
          } else {
            nodeClassList.add("read");
          }
        });
      }
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    this.topics.forEach(topic => {
      const includeUnreadIndicator =
        typeof topic.unread_by_group_member !== "undefined";

      if (includeUnreadIndicator) {
        const unreadIndicatorChannel = `/private-messages/unread-indicator/${topic.id}`;
        this.messageBus.unsubscribe(unreadIndicatorChannel);
      }
    });
  },

  @discourseComputed("topics")
  showUnreadIndicator(topics) {
    return topics.some(
      topic => typeof topic.unread_by_group_member !== "undefined"
    );
  },

  click(e) {
    // Mobile basic-topic-list doesn't use the `topic-list-item` view so
    // the event for the topic entrance is never wired up.
    if (!this.site.mobileView) {
      return;
    }

    let target = $(e.target);
    if (target.closest(".posts-map").length) {
      const topicId = target.closest("tr").attr("data-topic-id");
      if (topicId) {
        if (target.prop("tagName") !== "A") {
          let targetLinks = target.find("a");
          if (targetLinks.length) {
            target = targetLinks;
          } else {
            targetLinks = target.closest("a");
            if (targetLinks.length) {
              target = targetLinks;
            } else {
              return false;
            }
          }
        }

        const topic = this.topics.findBy("id", parseInt(topicId, 10));
        this.appEvents.trigger("topic-entrance:show", {
          topic,
          position: target.offset()
        });
      }
      return false;
    }
  }
});
