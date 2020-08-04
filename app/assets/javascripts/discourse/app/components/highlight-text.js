import highlightSearch from "discourse/components/highlight-search";
import deprecated from "discourse-common/lib/deprecated";

export default highlightSearch.extend({
  init() {
    this._super(...arguments);
    deprecated(
      "`highlight-text` component is deprecated,  use the `highlight-search` instead."
    );
  }
});
