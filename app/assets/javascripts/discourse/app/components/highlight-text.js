import deprecated from "discourse-common/lib/deprecated";
import highlightSearch from "discourse/components/highlight-search";

export default highlightSearch.extend({
  init() {
    this._super(...arguments);
    deprecated(
      "`highlight-text` component is deprecated,  use the `highlight-search` instead.",
      { id: "discourse.highlight-text-component" }
    );
  },
});
