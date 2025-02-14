import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { isEmpty, isPresent } from "@ember/utils";
import { eq, or } from "truth-helpers";
import AsyncContent from "discourse/components/async-content";
import TopicStatus from "discourse/components/topic-status";
import boundCategoryLink from "discourse/helpers/bound-category-link";
import replaceEmoji from "discourse/helpers/replace-emoji";
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
  @tracked topicTitle = null;

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
    next(() => this.chooseTopic(null)); // clear existing selection

    // topicTitle is null => initial load
    if (this.topicTitle === null) {
      if (this.args.loadOnInit && isPresent(this.args.additionalFilters)) {
        return await this.initialSearch();
      } else {
        return;
      }
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
      next(() => this.chooseTopic(topics[0]));
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
    <div class="choose-topic">
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

      <div class="choose-topic__search-results">
        <AsyncContent
          @asyncData={{this.loadTopics}}
          @context={{this.topicTitle}}
          @debounce={{true}}
        >
          <:loading>
            {{i18n "loading"}}
          </:loading>

          <:empty>
            {{#if this.topicTitle}}
              {{i18n "choose_topic.none_found"}}
            {{else}}
              {{! ensure the paragraph has the same height as the loading message to prevent layout shift }}
              &nbsp;
            {{/if}}
          </:empty>

          <:content as |topics|>
            <div class="choose-topic-list" role="radiogroup">
              {{#each topics as |t|}}
                <div class="controls existing-topic">
                  <label class="radio">
                    <input
                      {{on "click" (fn this.chooseTopic t)}}
                      checked={{eq t.id @selectedTopicId}}
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
          </:content>
        </AsyncContent>
      </div>
    </div>
  </template>
}
