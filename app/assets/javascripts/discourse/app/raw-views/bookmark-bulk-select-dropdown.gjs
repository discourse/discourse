import EmberObject from "@ember/object";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import i18n from "discourse-common/helpers/i18n";
import BulkSelectBookmarksDropdown from "select-kit/components/bulk-select-bookmarks-dropdown";

export default class extends EmberObject {
  get selectedCount() {
    return this.bulkSelectHelper.selected.length;
  }

  get html() {
    return rawRenderGlimmer(
      this,
      "div.bulk-select-bookmarks-dropdown",
      <template>
        <span class="bulk-select-bookmark-dropdown__count">
          {{i18n "bookmarks.bulk.selected_count" count=@data.selectedCount}}
        </span>
        <BulkSelectBookmarksDropdown
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
