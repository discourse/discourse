import EmberObject from "@ember/object";
import BulkSelectTopicsDropdown from "discourse/components/bulk-select-topics-dropdown";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import i18n from "discourse-common/helpers/i18n";

export default class extends EmberObject {
  get selectedCount() {
    return this.bulkSelectHelper.selected.length;
  }

  get html() {
    return rawRenderGlimmer(
      this,
      "div.bulk-select-topics-dropdown",
      <template>
        <span class="bulk-select-topic-dropdown__count">
          {{i18n "topics.bulk.selected_count" count=@data.selectedCount}}
        </span>
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
