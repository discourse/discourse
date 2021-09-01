import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import discourseDebounce from "discourse-common/lib/debounce";
import { isEmpty } from "@ember/utils";
import { next, schedule } from "@ember/runloop";
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
        if (results && results.posts && results.posts.length > 0) {
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
    schedule("afterRender", () => {
      $("#choose-topic-title").keydown((e) => {
        if (e.key === "Enter") {
          return false;
        }
      });
    });
  },

  willDestroyElement() {
    this._super(...arguments);
    $("#choose-topic-title").off("keydown");
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

    searchForTerm(titleWithFilters, searchParams).then((results) => {
      // search term changed after the request was fired but before we
      // got a response, ignore results.
      if (title !== this.topicTitle) {
        return;
      }
      if (results && results.posts && results.posts.length > 0) {
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

  actions: {
    chooseTopic(topic) {
      this.set("selectedTopicId", topic.id);
      next(() => {
        document.getElementById(`choose-topic-${topic.id}`).checked = true;
      });
      if (this.topicChangedCallback) {
        this.topicChangedCallback(topic);
      }
    },
  },
});
