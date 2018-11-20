import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Ember.Object.extend({
  searchContextEnabled: false, // checkbox to scope search
  searchContext: null,
  term: null,
  highlightTerm: null,

  @observes("term")
  _sethighlightTerm() {
    this.set("highlightTerm", this.get("term"));
  },

  @computed("searchContext")
  contextType: {
    get(searchContext) {
      if (searchContext) {
        return Ember.get(searchContext, "type");
      }
    },
    set(value, searchContext) {
      // a bit hacky, consider cleaning this up, need to work through all observers though
      const context = $.extend({}, searchContext);
      context.type = value;
      this.set("searchContext", context);
      return this.get("searchContext.type");
    }
  }
});
