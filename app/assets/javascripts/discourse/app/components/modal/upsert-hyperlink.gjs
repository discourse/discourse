import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import TopicStatus from "discourse/components/topic-status";
import categoryLink from "discourse/helpers/category-link";
import discourseTags from "discourse/helpers/discourse-tags";
import loadingSpinner from "discourse/helpers/loading-spinner";
import replaceEmoji from "discourse/helpers/replace-emoji";
import discourseDebounce from "discourse/lib/debounce";
import { searchForTerm } from "discourse/lib/search";
import { prefixProtocol } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class UpsertHyperlink extends Component {
  @tracked selectedRow = -1;
  @tracked searchResults = [];
  @tracked searchLoading = false;
  #debounced;
  #activeSearch;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#debounced);
  }

  @cached
  get data() {
    return {
      linkUrl: this.args.model.linkUrl ?? "",
      linkText: this.args.model.linkText ?? "",
    };
  }

  highlightRow(e, direction) {
    const index =
      direction === "down" ? this.selectedRow + 1 : this.selectedRow - 1;

    if (index > -1 && index < this.searchResults.length) {
      document
        .querySelectorAll(".internal-link-results .search-link")
        [index].focus();
      this.selectedRow = index;
    } else {
      this.selectedRow = -1;
      document.querySelector("input.link-url").focus();
    }

    e.preventDefault();
  }

  selectLink(el) {
    this.searchResults = [];

    this.formApi.setProperties({
      linkUrl: el.href,
      linkText: el.dataset.title,
    });

    this.selectedRow = -1;
    document.querySelector("input.link-text").focus();
  }

  async triggerSearch(linkUrl) {
    if (!linkUrl || linkUrl.length < 4 || linkUrl.startsWith("http")) {
      this.abortSearch();
      return;
    }

    this.searchLoading = true;
    this.#activeSearch = searchForTerm(linkUrl, {
      typeFilter: "topic",
    });

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
        // override Enter behavior when a row is selected
        if (this.selectedRow > -1) {
          const selected = document.querySelectorAll(
            ".internal-link-results .search-link"
          )[this.selectedRow];
          this.selectLink(selected);
        }

        // this would ideally be handled by nesting a submit button within the form tag
        // but it's tricky with the current modal api
        if (event.target.tagName === "INPUT") {
          this.formApi.submit();
        }

        event.preventDefault();
        event.stopPropagation();

        break;
      case "Escape":
        // Esc should cancel dropdown first
        if (this.searchResults.length) {
          this.searchResults = [];
          event.preventDefault();
          event.stopPropagation();
        } else {
          this.args.closeModal();
          document.querySelector(".d-editor-input")?.focus();
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
  onFormSubmit(data) {
    const origLink = data.linkUrl;
    const linkUrl = encodeURI(prefixProtocol(origLink));
    const sel = this.args.model.toolbarEvent.selected;

    if (isEmpty(linkUrl)) {
      return;
    }

    const linkText = data.linkText || sel.value || origLink || "";
    this.args.model.toolbarEvent.addText(`[${linkText.trim()}](${linkUrl})`);

    this.args.closeModal();
  }

  @action
  linkClick(e) {
    if (!e.metaKey && !e.ctrlKey) {
      e.preventDefault();
      e.stopPropagation();
      this.selectLink(e.target.closest(".search-link"));
    }
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  search(value) {
    this.formApi.set("linkUrl", value);
    this.#debounced = discourseDebounce(this, this.triggerSearch, value, 400);
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <DModal
      {{on "keydown" this.keyDown}}
      {{on "mousedown" this.mouseDown}}
      @closeModal={{@closeModal}}
      @title={{i18n
        (if
          @model.editing "composer.link_edit_title" "composer.link_dialog_title"
        )
      }}
      @bodyClass="insert-link"
      class="upsert-hyperlink-modal"
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
              @name="linkUrl"
              @title={{i18n "composer.link_url_label"}}
              @format="full"
              @validation="required"
              @onSet={{this.search}}
              as |field|
            >
              <field.Input
                placeholder={{i18n "composer.link_url_placeholder"}}
                class="link-url"
                autofocus="autofocus"
              />
            </form.Field>

            {{#if this.searchLoading}}
              {{loadingSpinner}}
            {{/if}}

            {{#if this.searchResults}}
              <div class="internal-link-results">
                {{#each this.searchResults as |result|}}
                  <a
                    {{on "click" this.linkClick}}
                    href={{result.url}}
                    data-title={{result.fancy_title}}
                    class="search-link"
                  >
                    <TopicStatus @topic={{result}} @disableActions={{true}} />
                    {{replaceEmoji result.title}}
                    <div class="search-category">
                      {{#if result.category.parentCategory}}
                        {{categoryLink result.category.parentCategory}}
                      {{/if}}
                      {{categoryLink result.category hideParent=true}}
                      {{discourseTags result}}
                    </div>
                  </a>
                {{/each}}
              </div>
            {{/if}}

            <form.Field
              @name="linkText"
              @title={{i18n "composer.link_text_label"}}
              @format="full"
              as |field|
            >
              <field.Input
                placeholder={{i18n "composer.link_optional_text"}}
                class="link-text"
              />
            </form.Field>
          </Form>
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.formApi.submit}}
          @label={{if
            @model.editing
            "composer.link_edit_action"
            "composer.link_dialog_action"
          }}
          type="submit"
          class="btn-primary"
        />

        <DButton
          @action={{@closeModal}}
          @label="composer.cancel"
          class="btn-transparent"
        />
      </:footer>
    </DModal>
  </template>
}
