import Component from "@ember/component";
import { action, get } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { next } from "@ember/runloop";
import { debounce, observes } from "discourse-common/utils/decorators";
import { searchForTerm } from "discourse/lib/search";

export default Component.extend({
  loading: null,
  noResults: null,
  messages: null,
  topicChangedCallback: null,

  @observes("messageTitle")
  messageTitleChanged() {
    this.setProperties({
      loading: true,
      noResults: true,
      selectedTopicId: null,
    });
    this.search(this.messageTitle);
  },

  @observes("messages")
  messagesChanged() {
    const messages = this.messages;
    if (messages) {
      this.set("noResults", messages.length === 0);
    }
    this.set("loading", false);
  },

  @debounce(300)
  search(title) {
    if (isEmpty(title)) {
      this.setProperties({ messages: null, loading: false });
      return;
    }

    searchForTerm(title, {
      typeFilter: "private_messages",
      searchForId: true,
      restrictToArchetype: "private_message",
    }).then((results) => {
      if (results?.posts?.length) {
        this.set(
          "messages",
          results.posts
            .mapBy("topic")
            .filter((t) => t.get("id") !== this.currentTopicId)
        );
      } else {
        this.setProperties({ messages: null, loading: false });
      }
    });
  },

  @action
  chooseMessage(message, event) {
    event?.preventDefault();
    const messageId = get(message, "id");
    this.set("selectedTopicId", messageId);

    if (this.topicChangedCallback) {
      this.topicChangedCallback(message);
    }

    next(() => $(`#choose-message-${messageId}`).prop("checked", "true"));
  },
});
