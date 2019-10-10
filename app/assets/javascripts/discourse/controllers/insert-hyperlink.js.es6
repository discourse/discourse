import ModalFunctionality from "discourse/mixins/modal-functionality";
import { searchForTerm } from "discourse/lib/search";
import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(ModalFunctionality, {
  onShow() {
    this.set("linkUrl", "");
    this.set("linkText", "");
    this.set("searchResults", []);
    this.set("selectedRow", -1);

    Ember.run.next(() => {
      const element = document.querySelector(".insert-link");

      element.addEventListener("keydown", e => {
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
              element.querySelector("input.link-text").focus();
              e.preventDefault();
              e.stopPropagation();
            }
            break;
        }
      });

      element
        .closest(".modal-inner-container")
        .addEventListener("mousedown", e => {
          if (!e.target.closest(".inputs")) {
            this.set("searchResults", []);
          }
        });

      document.querySelector("input.link-url").focus();
    });
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
    this.set("selectedRow", -1);
  },

  @observes("linkUrl")
  triggerSearch() {
    if (
      this.linkUrl &&
      this.linkUrl.length > 3 &&
      !this.linkUrl.startsWith("http")
    ) {
      const searchTopics = function() {
        searchForTerm(this.linkUrl, { typeFilter: "topic" }).then(results => {
          if (results && results.topics && results.topics.length > 0) {
            this.set("searchResults", results.topics);
          } else {
            this.set("searchResults", []);
          }
        });
      };

      Ember.run.debounce(this, searchTopics, 400);
    } else {
      this.set("searchResults", []);
    }
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
    }
  }
});
