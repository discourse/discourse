import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import SearchResultEntry from "discourse/components/search-result-entry";
import { eq } from "discourse/truth-helpers";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSearchAnswer from "./ai-search-answer";
import AiSearchBestMatch from "./ai-search-best-match";
import AiSearchConversation from "./ai-search-conversation";

export default class AiSearchPage extends Component {
  @service aiSearchSession;

  @tracked inputValue = this.args.query || "";

  #startTimer = null;

  constructor() {
    super(...arguments);

    // after this render, which may already have read the state starting
    // changes
    this.#startTimer = next(() => {
      const query = this.inputValue.trim();
      if (query && !this.args.topicId && !this.pageActiveFor(query)) {
        this.session.start(query, "page", null, { trigger: "page" });
      }
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#startTimer);
  }

  get session() {
    return this.aiSearchSession;
  }

  // the header search shares the session, so a search started there is not
  // this page's to show
  get pageActive() {
    return this.session.surface === "page" && Boolean(this.session.query);
  }

  get keywordResults() {
    const posts = this.session.keywordPosts || [];
    const best = this.session.bestMatchIds(posts.map((post) => post.topic_id));
    return posts.map((post) => ({ post, bestMatch: best.has(post.topic_id) }));
  }

  get semanticOnlyResults() {
    if (!this.session.answerSettled || this.session.keywordPosts?.length) {
      return [];
    }
    return this.session.semanticPosts || [];
  }

  pageActiveFor(query) {
    return this.session.surface === "page" && this.session.isActiveFor(query);
  }

  @action
  updateInput(event) {
    this.inputValue = event.target.value;
  }

  @action
  submitSearch(event) {
    event.preventDefault();
    const query = this.inputValue.trim();
    if (query) {
      this.args.onQueryChange?.(query);
      this.session.start(query, "page", null, { trigger: "page" });
    }
  }

  @action
  useOriginalKeywords(event) {
    event.preventDefault();
    this.session.useOriginalKeywords();
  }

  <template>
    <div
      class={{dConcatClass
        "ai-search"
        (if @topicId "--conversation" "--results")
      }}
    >
      {{#if @topicId}}
        <AiSearchConversation @scope={{@scope}} @topicId={{@topicId}} />
      {{else}}
        <form class="ai-search__query" {{on "submit" this.submitSearch}}>
          {{dIcon "magnifying-glass"}}
          <input
            aria-label={{i18n "discourse_ai.ai_search.input_label"}}
            class="ai-search__query-input"
            maxlength="1000"
            placeholder={{i18n "discourse_ai.ai_search.input_placeholder"}}
            type="search"
            value={{this.inputValue}}
            {{on "input" this.updateInput}}
          />
        </form>

        {{#if this.pageActive}}
          <AiSearchAnswer />

          <section class="ai-search__keyword-results">
            {{#if this.session.showingRewrittenKeywords}}
              <a
                class="ai-search__use-original"
                href
                {{on "click" this.useOriginalKeywords}}
              >
                {{i18n
                  "discourse_ai.ai_search.use_original"
                  query=this.session.query
                }}
              </a>
            {{/if}}

            {{#if (eq this.session.keywordPosts null)}}
              <DSkeleton @count={{6}} @lastLineWidth="70%" />
            {{else}}
              <div class="fps-result-entries" role="list">
                {{#each this.keywordResults as |result|}}
                  <div class="ai-search__result">
                    {{#if result.bestMatch}}
                      <AiSearchBestMatch />
                    {{/if}}
                    <SearchResultEntry
                      @highlightQuery={{this.session.keywordQuery}}
                      @post={{result.post}}
                    />
                  </div>
                {{else}}
                  {{#if this.semanticOnlyResults.length}}
                    <p class="ai-search__keyword-empty">
                      {{i18n "discourse_ai.ai_search.semantic_fallback"}}
                    </p>
                    {{#each this.semanticOnlyResults as |post|}}
                      <SearchResultEntry @post={{post}} />
                    {{/each}}
                  {{else}}
                    <p class="ai-search__keyword-empty">
                      {{i18n "discourse_ai.ai_search.no_keyword_results"}}
                    </p>
                  {{/if}}
                {{/each}}
              </div>
            {{/if}}
          </section>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
