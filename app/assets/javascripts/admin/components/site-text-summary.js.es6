import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["site-text"],
  classNameBindings: ["siteText.overridden"],

  @on("didInsertElement")
  highlightTerm() {
    const term = this._searchTerm();

    if (term) {
      this.$(".site-text-id, .site-text-value").highlight(term, {
        className: "text-highlight"
      });
    }
    this.$(".site-text-value").ellipsis();
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
