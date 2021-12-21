import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { action } from "@ember/object";
import discourseDebounce from "discourse-common/lib/debounce";
import { isEmpty } from "@ember/utils";
import { searchForTerm } from "discourse/lib/search";
import { INPUT_DELAY } from "discourse-common/config/environment";

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
      searchForTerm(this.additionalFilters, {}).then((results) => {
        if (results?.posts?.length > 0) {
          this.set(
            "topics",
            results.posts
              .mapBy("topic")
              .filter((t) => t.id !== this.currentTopicId)
          );
        } else {
          this.setProperties({ topics: null, loading: false });
        }
      });
    }
  },

  didInsertElement() {
    this._super(...arguments);

    document
      .getElementById("choose-topic-title")
      .addEventListener("keydown", this._handleEnter);
  },

  willDestroyElement() {
    this._super(...arguments);

    document
      .getElementById("choose-topic-title")
      .removeEventListener("keydown", this._handleEnter);
  },

  @observes("topicTitle")
  topicTitleChanged() {
    if (this.oldTopicTitle === this.topicTitle) {
      return;
    }

    this.setProperties({
      loading: true,
      noResults: true,
      selectedTopicId: null,
      oldTopicTitle: this.topicTitle,
    });

    this.searchDebounced(this.topicTitle);
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

  searchDebounced(title) {
    discourseDebounce(this, this.search, title, INPUT_DELAY);
  },

  search(title) {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (isEmpty(title) && isEmpty(this.additionalFilters)) {
      this.setProperties({ topics: null, loading: false });
      this.onSearchEmptied?.();
      return;
    }

    const currentTopicId = this.currentTopicId;
    const titleWithFilters = `${title} ${this.additionalFilters}`;
    const searchParams = {};

    if (!isEmpty(title)) {
      searchParams.typeFilter = "topic";
      searchParams.restrictToArchetype = "regular";
      searchParams.searchForId = true;
    }

    searchForTerm(titleWithFilters, searchParams).then((results) => {
      // search term changed after the request was fired but before we
      // got a response, ignore results.
      if (title !== this.topicTitle) {
        return;
      }
      if (results?.posts?.length > 0) {
        this.set(
          "topics",
          results.posts.mapBy("topic").filter((t) => t.id !== currentTopicId)
        );
        if (this.topics.length === 1) {
          this.send("chooseTopic", this.topics[0]);
        }
      } else {
        this.setProperties({ topics: null, loading: false });
      }
    });
  },

  @action
  chooseTopic(topic) {
    this.set("selectedTopicId", topic.id);

    if (this.topicChangedCallback) {
      this.topicChangedCallback(topic);
    }
  },

  _handleEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault();
    }
  },
});
