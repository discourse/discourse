import Component from "@ember/component";
import { on } from "discourse-common/utils/decorators";
import highlightHTML from "discourse/lib/highlight-html";

export default Component.extend({
  classNames: ["site-text"],
  classNameBindings: ["siteText.overridden"],

  @on("didInsertElement")
  highlightTerm() {
    const term = this._searchTerm();

    if (term) {
      highlightHTML(
        this.element.querySelector(".site-text-id, .site-text-value"),
        term,
        {
          className: "text-highlight"
        }
      );
    }
    $(this.element.querySelector(".site-text-value")).ellipsis();
  },

  click() {
    this.editAction(this.siteText);
  },

  _searchTerm() {
    const regex = this.searchRegex;
    const siteText = this.siteText;

    if (regex && siteText) {
      const matches = siteText.value.match(new RegExp(regex, "i"));
      if (matches) return matches[0];
    }

    return this.term;
  }
});
