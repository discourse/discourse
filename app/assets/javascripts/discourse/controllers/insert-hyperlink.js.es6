import { isEmpty } from "@ember/utils";
import { debounce } from "@ember/runloop";
import { cancel } from "@ember/runloop";
import { scheduleOnce } from "@ember/runloop";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { searchForTerm } from "discourse/lib/search";

export default Controller.extend(ModalFunctionality, {
  _debounced: null,
  _activeSearch: null,

  onShow() {
    this.setProperties({
      linkUrl: "",
      linkText: "",
      searchResults: [],
      searchLoading: false,
      selectedRow: -1
    });

    scheduleOnce("afterRender", () => {
      const element = document.querySelector(".insert-link");

      element.addEventListener("keydown", e => this.keyDown(e));

      element
        .closest(".modal-inner-container")
        .addEventListener("mousedown", e => this.mouseDown(e));

      document.querySelector("input.link-url").focus();
    });
  },

  keyDown(e) {
    switch (e.which) {
      case 40:
        this.highlightRow(e, "down");
        break;
      case 38:
        this.highlightRow(e, "up");
        break;
      case 13:
        // override Enter behaviour when a row is selected
        if (this.selectedRow > -1) {
          const selected = document.querySelectorAll(
            ".internal-link-results .search-link"
          )[this.selectedRow];
          this.selectLink(selected);
          e.preventDefault();
          e.stopPropagation();
        }
        break;
      case 27:
        // Esc should cancel dropdown first
        if (this.searchResults.length) {
          this.set("searchResults", []);
          e.preventDefault();
          e.stopPropagation();
        }
        break;
    }
  },

  mouseDown(e) {
    if (!e.target.closest(".inputs")) {
      this.set("searchResults", []);
    }
  },

  highlightRow(e, direction) {
    const index =
      direction === "down" ? this.selectedRow + 1 : this.selectedRow - 1;

    if (index > -1 && index < this.searchResults.length) {
      document
        .querySelectorAll(".internal-link-results .search-link")
        [index].focus();
      this.set("selectedRow", index);
    } else {
      this.set("selectedRow", -1);
      document.querySelector("input.link-url").focus();
    }

    e.preventDefault();
  },

  selectLink(el) {
    this.setProperties({
      linkUrl: el.href,
      searchResults: [],
      selectedRow: -1
    });

    if (!this.linkText && el.dataset.title) {
      this.set("linkText", el.dataset.title);
    }

    document.querySelector("input.link-text").focus();
  },

  triggerSearch() {
    if (this.linkUrl.length > 3 && this.linkUrl.indexOf("http") === -1) {
      this.set("searchLoading", true);
      this._activeSearch = searchForTerm(this.linkUrl, {
        typeFilter: "topic"
      });
      this._activeSearch
        .then(results => {
          if (results && results.topics && results.topics.length > 0) {
            this.set("searchResults", results.topics);
          } else {
            this.set("searchResults", []);
          }
        })
        .finally(() => {
          this.set("searchLoading", false);
          this._activeSearch = null;
        });
    } else {
      this.abortSearch();
    }
  },

  abortSearch() {
    if (this._activeSearch) {
      this._activeSearch.abort();
    }
    this.setProperties({
      searchResults: [],
      searchLoading: false
    });
  },

  onClose() {
    const element = document.querySelector(".insert-link");
    element.removeEventListener("keydown", this.keyDown);
    element
      .closest(".modal-inner-container")
      .removeEventListener("mousedown", this.mouseDown);

    cancel(this._debounced);
  },

  actions: {
    ok() {
      const origLink = this.linkUrl;
      const linkUrl =
        origLink.indexOf("://") === -1 ? `http://${origLink}` : origLink;
      const sel = this.toolbarEvent.selected;

      if (isEmpty(linkUrl)) {
        return;
      }

      const linkText = this.linkText || "";

      if (linkText.length) {
        this.toolbarEvent.addText(`[${linkText}](${linkUrl})`);
      } else {
        if (sel.value) {
          this.toolbarEvent.addText(`[${sel.value}](${linkUrl})`);
        } else {
          this.toolbarEvent.addText(`[${origLink}](${linkUrl})`);
          this.toolbarEvent.selectText(sel.start + 1, origLink.length);
        }
      }
      this.send("closeModal");
    },
    cancel() {
      this.send("closeModal");
    },
    linkClick(e) {
      if (!e.metaKey && !e.ctrlKey) {
        e.preventDefault();
        e.stopPropagation();
        this.selectLink(e.target.closest(".search-link"));
      }
    },
    search() {
      this._debounced = debounce(this, this.triggerSearch, 400);
    }
  }
});
