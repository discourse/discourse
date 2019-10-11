import ModalFunctionality from "discourse/mixins/modal-functionality";
import { searchForTerm } from "discourse/lib/search";

export default Ember.Controller.extend(ModalFunctionality, {
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

    Ember.run.scheduleOnce("afterRender", () => {
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
        this.selectRow(e, "down");
        break;
      case 38:
        this.selectRow(e, "up");
        break;
      case 13:
        // override Enter behaviour when a row is selected
        if (this.selectedRow > -1) {
          this.setUpdated(this.selectedRow);
          document.querySelector("input.link-text").focus();
          e.preventDefault();
          e.stopPropagation();
        }
        break;
      case 27:
        // override Esc too
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

  selectRow(e, direction) {
    const index =
      direction === "down" ? this.selectedRow + 1 : this.selectedRow - 1;

    if (index > -1 && index < this.searchResults.length) {
      document
        .querySelectorAll(".internal-link-results .search-link")
        [index].focus();
      this.set("selectedRow", index);
    } else {
      this.set("selectedRow", -1);
      document.querySelector("input.link-text").focus();
    }

    e.preventDefault();
  },

  setUpdated(index) {
    const topic = this.searchResults[index];
    if (topic) {
      this.set("linkUrl", Discourse.BaseUrl + topic.url);
      if (!this.linkText) {
        this.set("linkText", topic.title);
      }
    }
    this.setProperties({
      searchResults: [],
      selectedRow: -1
    });
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

    Ember.run.cancel(this._debounced);
  },

  actions: {
    ok() {
      const origLink = this.linkUrl;
      const linkUrl =
        origLink.indexOf("://") === -1 ? `http://${origLink}` : origLink;
      const sel = this._lastSel;

      if (Ember.isEmpty(linkUrl)) {
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
    select(index) {
      this.setUpdated(index);
    },
    search(value) {
      this._debounced = Ember.run.debounce(this, this.triggerSearch, 400);
    }
  }
});
