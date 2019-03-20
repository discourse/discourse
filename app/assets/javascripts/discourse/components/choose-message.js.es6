import debounce from "discourse/lib/debounce";
import { searchForTerm } from "discourse/lib/search";
import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
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
    this.search(this.get("messageTitle"));
  },

  @observes("messages")
  messagesChanged() {
    const messages = this.get("messages");
    if (messages) {
      this.set("noResults", messages.length === 0);
    }
    this.set("loading", false);
  },

  search: debounce(function(title) {
    const currentTopicId = this.get("currentTopicId");

    if (Ember.isEmpty(title)) {
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
      const messageId = Ember.get(message, "id");
      this.set("selectedTopicId", messageId);
      Ember.run.next(() =>
        $(`#choose-message-${messageId}`).prop("checked", "true")
      );
      return false;
    }
  }
});
