import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
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
import DSelectTopic from "discourse/ui-kit/select/recipes/topics/d-select-topic";
import { i18n } from "discourse-i18n";

export default class BoardsAddTopicAsCard extends Component {
  @service siteSettings;

  @tracked selectedRow = -1;
  @tracked searchResults = [];
  @tracked searchLoading = false;
  @tracked pickedTopic = null;
  data = { topicSearch: "" };
  #debounced;
  #activeSearch;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#debounced);
  }

  /** The held topic, as the field's known topics, so it shows without a lookup. */
  get pickedTopics() {
    return this.pickedTopic ? [this.pickedTopic] : [];
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
    // TODO (select-kit-replacement-cleanup): The topic list handles its own keys.
    if (this.siteSettings.enable_new_select_controls) {
      return;
    }
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
    if (this.siteSettings.enable_new_select_controls) {
      return;
    }
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
  pickTopic(_topicId, topic) {
    this.pickedTopic = topic ?? null;
  }

  @action
  addPickedTopic() {
    this.args.model.onAddTopicAsCard({
      topicId: this.pickedTopic.id,
      title: this.pickedTopic.fancy_title,
    });
    this.args.closeModal();
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

  <template>
    {{! eslint-disable ember/template-no-pointer-down-event-binding }}
    <DModal
      class="discourse-boards-add-topic-as-card-modal"
      @bodyClass="insert-link"
      @closeModal={{@closeModal}}
      @title={{i18n "boards.board.add_topic_as_card"}}
      {{on "keydown" this.keyDown}}
      {{on "mousedown" this.mouseDown}}
    >
      <:body>
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy search after rollout. }}
        {{#if this.siteSettings.enable_new_select_controls}}
          <label
            class="boards-add-topic-as-card__label"
            for="boards-add-topic-as-card-topic"
          >
            {{i18n "boards.board.topic_search_placeholder"}}
          </label>
          <DSelectTopic
            @archetype={{null}}
            @clearable={{true}}
            @id="boards-add-topic-as-card-topic"
            @onChange={{this.pickTopic}}
            @texts={{hash
              placeholder=(i18n "boards.board.topic_search_placeholder")
              searchPlaceholder=(i18n "boards.board.topic_search_placeholder")
            }}
            @topics={{this.pickedTopics}}
            @value={{this.pickedTopic.id}}
          />
        {{else}}
          <div class="inputs">
            <Form
              @data={{this.data}}
              @onRegisterApi={{this.registerApi}}
              @onSubmit={{this.onFormSubmit}}
              as |form|
            >
              <form.Field
                @format="full"
                @name="topicSearch"
                @onSet={{this.search}}
                @title={{i18n "boards.board.topic_search_placeholder"}}
                @type="input"
                as |field|
              >
                <field.Control
                  autofocus="autofocus"
                  class="topic-search-input"
                  placeholder={{i18n "boards.board.topic_search_placeholder"}}
                />
              </form.Field>

              {{#if this.searchLoading}}
                {{dLoadingSpinner}}
              {{/if}}

              {{#if this.searchResults}}
                <div class="internal-link-results">
                  {{#each this.searchResults as |result|}}
                    <a
                      class="search-link"
                      data-title={{result.fancy_title}}
                      data-topic-id={{result.id}}
                      href={{result.url}}
                      {{on "click" this.topicClick}}
                    >
                      <TopicStatus @disableActions={{true}} @topic={{result}} />
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
        {{/if}}
      </:body>

      <:footer>
        {{#if this.siteSettings.enable_new_select_controls}}
          <DButton
            class="btn-primary"
            @action={{this.addPickedTopic}}
            @disabled={{not this.pickedTopic}}
            @label="boards.board.add_topic_as_card"
          />
        {{else}}
          <DButton
            class="btn-primary"
            type="submit"
            @action={{this.formApi.submit}}
            @label="boards.board.add_topic_as_card"
          />
        {{/if}}
        <DButton
          class="btn-transparent"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
