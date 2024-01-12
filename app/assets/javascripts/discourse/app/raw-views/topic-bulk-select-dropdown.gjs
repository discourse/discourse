import EmberObject from "@ember/object";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import BulkSelectTopicsDropdown from "select-kit/components/bulk-select-topics-dropdown";

export default class extends EmberObject {
  get selectedCount() {
    return this.bulkSelectHelper.selected.length;
  }

  get html() {
    return rawRenderGlimmer(
      this,
      "div.bulk-select-topics-dropdown",
      <template>
        <span>{{@data.selectedCount}} selected</span>
        <BulkSelectTopicsDropdown
          @bulkSelectHelper={{@data.bulkSelectHelper}}
        />
      </template>,
      {
        bulkSelectHelper: this.bulkSelectHelper,
        selectedCount: this.selectedCount,
      }
    );
  }
}
