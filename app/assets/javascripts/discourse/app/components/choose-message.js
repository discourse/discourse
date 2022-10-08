import Component from "@ember/component";
import discourseDebounce from "discourse-common/lib/debounce";
import { action, get } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { next } from "@ember/runloop";
import { observes } from "discourse-common/utils/decorators";
import { searchForTerm } from "discourse/lib/search";

export default Component.extend({
  loading: null,
  noResults: null,
  messages: null,

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

  search(title) {
    discourseDebounce(
      this,
      function () {
        const currentTopicId = this.currentTopicId;

        if (isEmpty(title)) {
          this.setProperties({ messages: null, loading: false });
          return;
        }

        searchForTerm(title, {
          typeFilter: "private_messages",
          searchForId: true,
          restrictToArchetype: "private_message",
        }).then((results) => {
          if (results && results.posts && results.posts.length > 0) {
            this.set(
              "messages",
              results.posts
                .mapBy("topic")
                .filter((t) => t.get("id") !== currentTopicId)
            );
          } else {
            this.setProperties({ messages: null, loading: false });
          }
        });
      },
      title,
      300
    );
  },

  @action
  chooseMessage(message, event) {
    event?.preventDefault();
    const messageId = get(message, "id");
    this.set("selectedTopicId", messageId);
    next(() => $(`#choose-message-${messageId}`).prop("checked", "true"));
  },
});
