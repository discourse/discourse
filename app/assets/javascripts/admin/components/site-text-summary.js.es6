import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["site-text"],
  classNameBindings: ["siteText.overridden"],

  @on("didInsertElement")
  highlightTerm() {
    const term = this.get("term");
    if (term) {
      this.$(".site-text-id, .site-text-value").highlight(term, {
        className: "text-highlight"
      });
    }
    this.$(".site-text-value").ellipsis();
  },

  click() {
    this.send("edit");
  },

  actions: {
    edit() {
      this.sendAction("editAction", this.get("siteText"));
    }
  }
});
