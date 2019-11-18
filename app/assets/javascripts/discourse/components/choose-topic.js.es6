import { isEmpty } from "@ember/utils";
import { next } from "@ember/runloop";
import Component from "@ember/component";
import discourseDebounce from "discourse/lib/debounce";
import { searchForTerm } from "discourse/lib/search";
import { observes } from "discourse-common/utils/decorators";

export default Component.extend({
  loading: null,
  noResults: null,
  topics: null,
  selectedTopicId: null,
  currentTopicId: null,
  topicTitle: null,

  @observes("topicTitle")
  topicTitleChanged() {
    this.setProperties({
      loading: true,
      noResults: true,
      selectedTopicId: null
    });

    this.search(this.topicTitle);
  },

  @observes("topics")
  topicsChanged() {
    if (this.topics) {
      this.set("noResults", this.topics.length === 0);
    }

    this.set("loading", false);
  },

  search: discourseDebounce(function(title) {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    const currentTopicId = this.currentTopicId;

    if (isEmpty(title)) {
      this.setProperties({ topics: null, loading: false });
      return;
    }

    searchForTerm(title, {
      typeFilter: "topic",
      searchForId: true,
      restrictToArchetype: "regular"
    }).then(results => {
      if (results && results.posts && results.posts.length > 0) {
        this.set(
          "topics",
          results.posts.mapBy("topic").filter(t => t.id !== currentTopicId)
        );
      } else {
        this.setProperties({ topics: null, loading: false });
      }
    });
  }, 300),

  actions: {
    chooseTopic(topic) {
      this.set("selectedTopicId", topic.id);
      next(() => {
        document.getElementById(`choose-topic-${topic.id}`).checked = true;
      });
      return false;
    }
  }
});
