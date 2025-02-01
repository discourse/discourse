import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty, isPresent } from "@ember/utils";
import { eq, not, or } from "truth-helpers";
import AsyncContent from "discourse/components/async-content";
import TopicStatus from "discourse/components/topic-status";
import boundCategoryLink from "discourse/helpers/bound-category-link";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { INPUT_DELAY } from "discourse/lib/environment";
import { searchForTerm } from "discourse/lib/search";
import { i18n } from "discourse-i18n";

// args:
// topicChangedCallback
//
// optional:
// currentTopicId
// additionalFilters
// label
// loadOnInit
export default class ChooseTopic extends Component {
  @tracked topicTitle;
  #loadInit = this.args.loadOnInit;

  async initialSearch() {
    const results = await searchForTerm(this.args.additionalFilters);
    if (!results?.posts?.length) {
      return;
    }

    return results.posts
      .mapBy("topic")
      .filter((t) => t.id !== this.args.currentTopicId);
  }

  @action
  async loadTopics(title) {
    if (this.#loadInit && isPresent(this.args.additionalFilters)) {
      this.#loadInit = false;
      return await this.initialSearch();
    }

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (isEmpty(title) && isEmpty(this.args.additionalFilters)) {
      return null;
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

    const results = await searchForTerm(titleWithFilters, searchParams);

    // search term changed after the request was fired but before we
    // got a response, ignore results.
    if (title !== this.topicTitle) {
      return;
    }

    if (!results?.posts?.length) {
      return null;
    }

    const topics = results.posts
      .mapBy("topic")
      .filter((t) => t.id !== this.args.currentTopicId);

    if (topics.length === 1) {
      this.chooseTopic(topics[0]);
    }

    return topics;
  }

  @action
  async onTopicTitleChange(event) {
    this.topicTitle = event.target.value;
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

  <template>
    <div>
      <label for="choose-topic-title">
        <span>{{i18n (or @label "choose_topic.title.search")}}</span>
      </label>

      <input
        {{on "keydown" this.ignoreEnter}}
        {{on "input" this.onTopicTitleChange}}
        type="text"
        placeholder={{i18n "choose_topic.title.placeholder"}}
        id="choose-topic-title"
      />

      <AsyncContent
        @asyncData={{this.loadTopics}}
        @context={{this.topicTitle}}
        @debounce={{INPUT_DELAY}}
        @loadOnInit={{@loadOnInit}}
      >
        <:loading>
          <p>{{i18n "loading"}}</p>
        </:loading>
        <:content as |topics|>
          {{#if (not topics.length)}}
            <p>{{i18n "choose_topic.none_found"}}</p>
          {{else}}
            <div class="choose-topic-list" role="radiogroup">
              {{#each topics as |t|}}
                <div class="controls existing-topic">
                  <label class="radio">
                    <input
                      {{on "click" (fn this.chooseTopic t)}}
                      checked={{eq t.id this.selectedTopicId}}
                      type="radio"
                      name="choose_topic_id"
                      id={{concat "choose-topic-" t.id}}
                    />
                    <TopicStatus @topic={{t}} @disableActions={{true}} />
                    <span class="topic-title">
                      {{replaceEmoji t.title}}
                    </span>
                    <span class="topic-categories">
                      {{boundCategoryLink
                        t.category
                        ancestors=t.category.predecessors
                        hideParent=true
                        link=false
                      }}
                    </span>
                  </label>
                </div>
              {{/each}}
            </div>
          {{/if}}
        </:content>
      </AsyncContent>
    </div>
  </template>
}
