import Service from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";

export default Service.extend({
  searchContextEnabled: false, // checkbox to scope search
  searchContext: null,
  highlightTerm: null,

  @discourseComputed("searchContext")
  contextType: {
    get(searchContext) {
      return searchContext?.type;
    },

    set(value, searchContext) {
      this.set("searchContext", { ...searchContext, type: value });

      return value;
    },
  },
});
