import { get } from "@ember/object";
import EmberObject from "@ember/object";
import discourseComputed, { observes } from "discourse-common/utils/decorators";

export default EmberObject.extend({
  searchContextEnabled: false, // checkbox to scope search
  searchContext: null,
  term: null,
  highlightTerm: null,

  @observes("term")
  _sethighlightTerm() {
    this.set("highlightTerm", this.term);
  },

  @discourseComputed("searchContext")
  contextType: {
    get(searchContext) {
      if (searchContext) {
        return get(searchContext, "type");
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
