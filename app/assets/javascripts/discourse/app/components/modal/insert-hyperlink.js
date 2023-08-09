import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import discourseDebounce from "discourse-common/lib/debounce";
import { isEmpty } from "@ember/utils";
import { prefixProtocol } from "discourse/lib/url";
import { searchForTerm } from "discourse/lib/search";

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
}
