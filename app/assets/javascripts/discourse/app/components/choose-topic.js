import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isEmpty, isPresent } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { debounce } from "discourse/lib/decorators";
import { searchForTerm } from "discourse/lib/search";
import { INPUT_DELAY } from "discourse-common/config/environment";

// args:
// topicChangedCallback
//
// optional:
// currentTopicId
// additionalFilters
// label
// loadOnInit
export default class ChooseTopic extends Component {
  @tracked loading = true;
  @tracked topics;
  topicTitle;

  constructor() {
    super(...arguments);

    if (this.args.loadOnInit && isPresent(this.args.additionalFilters)) {
      this.initialSearch();
    }
  }

  async initialSearch() {
    try {
      const results = await searchForTerm(this.args.additionalFilters);
      if (!results?.posts?.length) {
        return;
      }

      this.topics = results.posts
        .mapBy("topic")
        .filter((t) => t.id !== this.args.currentTopicId);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @debounce(INPUT_DELAY)
  async search(title) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (isEmpty(title) && isEmpty(this.args.additionalFilters)) {
      this.topics = null;
      this.loading = false;
      return;
    }

    const titleWithFilters = [title, this.args.additionalFilters]
      .filter(Boolean)
      .join(" ");
    let searchParams;

    if (isPresent(title)) {
      searchParams = {
        typeFilter: "topic",
        restrictToArchetype: "regular",
        searchForId: true,
      };
    }

    try {
      const results = await searchForTerm(titleWithFilters, searchParams);

      // search term changed after the request was fired but before we
      // got a response, ignore results.
      if (title !== this.topicTitle) {
        return;
      }

      if (!results?.posts?.length) {
        this.topics = null;
        return;
      }

      this.topics = results.posts
        .mapBy("topic")
        .filter((t) => t.id !== this.args.currentTopicId);

      if (this.topics.length === 1) {
        this.chooseTopic(this.topics[0]);
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  async onTopicTitleChange(event) {
    this.topicTitle = event.target.value;
    this.loading = true;

    await this.search(this.topicTitle);
  }

  @action
  ignoreEnter(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
    }
  }

  @action
  chooseTopic(topic) {
    this.args.topicChangedCallback(topic);
  }
}
