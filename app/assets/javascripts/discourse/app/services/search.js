import EmberObject, { get } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default EmberObject.extend({
  searchContextEnabled: false, // checkbox to scope search
  searchContext: null,
  highlightTerm: null,

  @discourseComputed("searchContext")
  contextType: {
    get(searchContext) {
      if (searchContext) {
        return get(searchContext, "type");
      }
    },
    set(value, searchContext) {
      // a bit hacky, consider cleaning this up, need to work through all observers though
      const context = Object.assign({}, searchContext);
      context.type = value;
      this.set("searchContext", context);
      return this.get("searchContext.type");
    },
  },
});
