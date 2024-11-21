import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import TopicStatus from "discourse/components/topic-status";
import categoryLink from "discourse/helpers/category-link";
import discourseTags from "discourse/helpers/discourse-tags";
import loadingSpinner from "discourse/helpers/loading-spinner";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { searchForTerm } from "discourse/lib/search";
import { prefixProtocol } from "discourse/lib/url";
import discourseDebounce from "discourse-common/lib/debounce";
import { i18n } from "discourse-i18n";

export default class InsertHyperlink extends Component {
  @tracked linkText = this.args.model.linkText;
  @tracked linkUrl = "";
  @tracked selectedRow = -1;
  @tracked searchResults = [];
  @tracked searchLoading = false;
  _debounced;
  _activeSearch;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this._debounced);
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
    this.linkUrl = el.href;
    this.selectedRow = -1;

    if (!this.linkText && el.dataset.title) {
      this.linkText = el.dataset.title;
    }

    document.querySelector("input.link-text").focus();
  }

  async triggerSearch() {
    if (this.linkUrl.length < 4 || this.linkUrl.startsWith("http")) {
      this.abortSearch();
      return;
    }

    this.searchLoading = true;
    this._activeSearch = searchForTerm(this.linkUrl, {
      typeFilter: "topic",
    });

    try {
      const results = await this._activeSearch;
      this.searchResults = results?.topics || [];
    } finally {
      this.searchLoading = false;
      this._activeSearch = null;
    }
  }

  abortSearch() {
    this._activeSearch?.abort();

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
          event.preventDefault();
          event.stopPropagation();
        }
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
  ok() {
    const origLink = this.linkUrl;
    const linkUrl = prefixProtocol(origLink);
    const sel = this.args.model.toolbarEvent.selected;

    if (isEmpty(linkUrl)) {
      return;
    }

    const linkText = this.linkText || "";

    if (linkText.length) {
      this.args.model.toolbarEvent.addText(`[${linkText}](${linkUrl})`);
    } else if (sel.value) {
      this.args.model.toolbarEvent.addText(`[${sel.value}](${linkUrl})`);
    } else {
      this.args.model.toolbarEvent.addText(`[${origLink}](${linkUrl})`);
      this.args.model.toolbarEvent.selectText(sel.start + 1, origLink.length);
    }

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
  updateLinkText(event) {
    this.linkText = event.target.value;
  }

  @action
  search(event) {
    this.linkUrl = event.target.value;
    this._debounced = discourseDebounce(this, this.triggerSearch, 400);
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <DModal
      {{on "keydown" this.keyDown}}
      {{on "mousedown" this.mouseDown}}
      @closeModal={{@closeModal}}
      @title={{i18n "composer.link_dialog_title"}}
      @bodyClass="insert-link"
      class="insert-hyperlink-modal"
    >
      <:body>
        <div class="inputs">
          <input
            {{on "input" this.search}}
            value={{this.linkUrl}}
            placeholder={{i18n "composer.link_url_placeholder"}}
            type="text"
            autofocus="autofocus"
            class="link-url"
          />

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
        </div>

        <div class="inputs">
          <input
            {{on "input" this.updateLinkText}}
            value={{this.linkText}}
            placeholder={{i18n "composer.link_optional_text"}}
            type="text"
            class="link-text"
          />
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.ok}}
          @label="composer.modal_ok"
          type="submit"
          class="btn-primary"
        />

        <DButton
          @action={{@closeModal}}
          @label="composer.cancel"
          class="btn-danger"
        />
      </:footer>
    </DModal>
  </template>
}
