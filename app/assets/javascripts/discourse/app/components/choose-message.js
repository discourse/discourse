import { get } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { next } from "@ember/runloop";
import Component from "@ember/component";
import discourseDebounce from "discourse/lib/debounce";
import { searchForTerm } from "discourse/lib/search";
import { observes } from "discourse-common/utils/decorators";

export default Component.extend({
  loading: null,
  noResults: null,
  messages: null,

  @observes("messageTitle")
  messageTitleChanged() {
    this.setProperties({
      loading: true,
      noResults: true,
      selectedTopicId: null
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

  search: discourseDebounce(function(title) {
    const currentTopicId = this.currentTopicId;

    if (isEmpty(title)) {
      this.setProperties({ messages: null, loading: false });
      return;
    }

    searchForTerm(title, {
      typeFilter: "private_messages",
      searchForId: true,
      restrictToArchetype: "private_message"
    }).then(results => {
      if (results && results.posts && results.posts.length > 0) {
        this.set(
          "messages",
          results.posts
            .mapBy("topic")
            .filter(t => t.get("id") !== currentTopicId)
        );
      } else {
        this.setProperties({ messages: null, loading: false });
      }
    });
  }, 300),

  actions: {
    chooseMessage(message) {
      const messageId = get(message, "id");
      this.set("selectedTopicId", messageId);
      next(() => $(`#choose-message-${messageId}`).prop("checked", "true"));
      return false;
    }
  }
});
