import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import Form from "discourse/components/form";
import TopicStatus from "discourse/components/topic-status";
import discourseDebounce from "discourse/lib/debounce";
import { withoutPrefix } from "discourse/lib/get-url";
import { searchForTerm } from "discourse/lib/search";
import DiscourseURL, { TOPIC_URL_REGEXP } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

export default class BoardsAddTopicAsCard extends Component {
  @tracked selectedRow = -1;
  @tracked searchResults = [];
  @tracked searchLoading = false;
  data = { topicSearch: "" };
  #debounced;
  #activeSearch;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#debounced);
  }

  highlightRow(e, direction) {
    const index =
      direction === "down" ? this.selectedRow + 1 : this.selectedRow - 1;

    if (index > -1 && index < this.searchResults.length) {
      document
        .querySelectorAll(".internal-link-results .search-link")
        [index]?.focus();
      this.selectedRow = index;
    } else {
      this.selectedRow = -1;
      document.querySelector("input.topic-search-input")?.focus();
    }

    e.preventDefault();
  }

  selectTopic(el) {
    const topicId = parseInt(el.dataset.topicId, 10);
    const title = el.dataset.title;
    if (topicId) {
      this.searchResults = [];
      this.args.model.onAddTopicAsCard({ topicId, title });
      this.args.closeModal();
    }
  }

  #topicIdFromInput(value) {
    const input = (value ?? "").trim();
    if (!input || !DiscourseURL.isInternal(input)) {
      return null;
    }

    let pathname;
    try {
      pathname = new URL(input, DiscourseURL.origin).pathname;
    } catch {
      return null;
    }

    const stripped = withoutPrefix(pathname);
    const match = TOPIC_URL_REGEXP.exec(stripped);
    if (!match || match.index !== 0 || match[0].length !== stripped.length) {
      return null;
    }
    return parseInt(match[2], 10);
  }

  async triggerSearch(value) {
    const looksLikeUrl = /^(?:https?:)?\/\//i.test(value ?? "");
    if (!value || value.length < 4 || looksLikeUrl) {
      this.abortSearch();
      return;
    }

    this.searchLoading = true;
    this.#activeSearch = searchForTerm(value, { typeFilter: "topic" });

    try {
      const results = await this.#activeSearch;
      this.searchResults = results?.topics || [];
    } finally {
      this.searchLoading = false;
      this.#activeSearch = null;
    }
  }

  abortSearch() {
    this.#activeSearch?.abort();
    this.searchResults = [];
    this.searchLoading = false;
  }

  @action
  keyDown(event) {
    switch (event.key) {
      case "ArrowDown":
        this.highlightRow(event, "down");
        break;
      case "ArrowUp":
        this.highlightRow(event, "up");
        break;
      case "Enter":
        if (this.selectedRow > -1) {
          const selected = document.querySelectorAll(
            ".internal-link-results .search-link"
          )[this.selectedRow];
          if (selected) {
            this.selectTopic(selected);
          }
          event.preventDefault();
          event.stopPropagation();
        } else if (event.target.tagName === "INPUT") {
          this.formApi?.submit();
          event.preventDefault();
          event.stopPropagation();
        }
        break;
      case "Escape":
        if (this.searchResults.length) {
          this.searchResults = [];
          event.preventDefault();
          event.stopPropagation();
        }
        break;
    }
  }

  @action
  mouseDown(event) {
    if (!event.target.closest(".inputs")) {
      this.searchResults = [];
    }
  }

  @action
  topicClick(event) {
    if (!event.metaKey && !event.ctrlKey) {
      event.preventDefault();
      event.stopPropagation();
      this.selectTopic(event.target.closest(".search-link"));
    }
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  search(value) {
    this.formApi.set("topicSearch", value);
    this.#debounced = discourseDebounce(this, this.triggerSearch, value, 400);
  }

  @action
  onFormSubmit(data) {
    const value = data.topicSearch?.trim();
    if (isEmpty(value)) {
      return;
    }

    const topicId = this.#topicIdFromInput(value);
    if (topicId) {
      this.searchResults = [];
      this.args.model.onAddTopicAsCard({ topicId, title: value });
      this.args.closeModal();
    }
  }

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding }}
    <DModal
      {{on "keydown" this.keyDown}}
      {{on "mousedown" this.mouseDown}}
      @closeModal={{@closeModal}}
      @title={{i18n "boards.board.add_topic_as_card"}}
      @bodyClass="insert-link"
      class="discourse-boards-add-topic-as-card-modal"
    >
      <:body>
        <div class="inputs">
          <Form
            @data={{this.data}}
            @onSubmit={{this.onFormSubmit}}
            @onRegisterApi={{this.registerApi}}
            as |form|
          >
            <form.Field
              @name="topicSearch"
              @type="input"
              @title={{i18n "boards.board.topic_search_placeholder"}}
              @format="full"
              @onSet={{this.search}}
              as |field|
            >
              <field.Control
                placeholder={{i18n "boards.board.topic_search_placeholder"}}
                class="topic-search-input"
                autofocus="autofocus"
              />
            </form.Field>

            {{#if this.searchLoading}}
              {{dLoadingSpinner}}
            {{/if}}

            {{#if this.searchResults}}
              <div class="internal-link-results">
                {{#each this.searchResults as |result|}}
                  <a
                    {{on "click" this.topicClick}}
                    href={{result.url}}
                    data-topic-id={{result.id}}
                    data-title={{result.fancy_title}}
                    class="search-link"
                  >
                    <TopicStatus @topic={{result}} @disableActions={{true}} />
                    {{dReplaceEmoji result.title}}
                    <div class="search-category">
                      {{#if result.category.parentCategory}}
                        {{dCategoryLink result.category.parentCategory}}
                      {{/if}}
                      {{dCategoryLink result.category hideParent=true}}
                      {{dDiscourseTags result}}
                    </div>
                  </a>
                {{/each}}
              </div>
            {{/if}}
          </Form>
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.formApi.submit}}
          @label="boards.board.add_topic_as_card"
          type="submit"
          class="btn-primary"
        />
        <DButton
          @action={{@closeModal}}
          @label="cancel"
          class="btn-transparent"
        />
      </:footer>
    </DModal>
  </template>
}
