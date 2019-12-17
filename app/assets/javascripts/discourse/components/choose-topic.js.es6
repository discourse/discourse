import { isEmpty } from "@ember/utils";
import { next } from "@ember/runloop";
import Component from "@ember/component";
import discourseDebounce from "discourse/lib/debounce";
import { searchForTerm } from "discourse/lib/search";
import { observes } from "discourse-common/utils/decorators";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  loading: null,
  noResults: null,
  topics: null,
  selectedTopicId: null,
  currentTopicId: null,
  additionalFilters: null,
  topicTitle: null,
  label: null,
  loadOnInit: false,
  topicChangedCallback: null,

  init() {
    this._super(...arguments);

    this.additionalFilters = this.additionalFilters || "";
    this.topicTitle = this.topicTitle || "";

    if (this.loadOnInit && !isEmpty(this.additionalFilters)) {
      searchForTerm(this.additionalFilters, {}).then(results => {
        if (results && results.posts && results.posts.length > 0) {
          this.set(
            "topics",
            results.posts
              .mapBy("topic")
              .filter(t => t.id !== this.currentTopicId)
          );
        } else {
          this.setProperties({ topics: null, loading: false });
        }
      });
    }
  },

  @observes("topicTitle")
  topicTitleChanged() {
    this.setProperties({
      loading: true,
      noResults: true,
      selectedTopicId: null
    });

    this.search(this.topicTitle);
  },

  @discourseComputed("label")
  labelText(label) {
    return label || "choose_topic.title.search";
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

    if (isEmpty(title) && isEmpty(this.additionalFilters)) {
      this.setProperties({ topics: null, loading: false });
      return;
    }

    const currentTopicId = this.currentTopicId;
    const titleWithFilters = `${title} ${this.additionalFilters}`;
    let searchParams = {};

    if (!isEmpty(title)) {
      searchParams.typeFilter = "topic";
      searchParams.restrictToArchetype = "regular";
      searchParams.searchForId = true;
    }

    searchForTerm(titleWithFilters, searchParams).then(results => {
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
      if (this.topicChangedCallback) this.topicChangedCallback(topic);
    }
  }
});
