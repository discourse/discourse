import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import BulkSelectTopicsDropdown from "discourse/components/bulk-select-topics-dropdown";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import { i18n } from "discourse-i18n";

const BulkSelectGlimmerWrapper = <template>
  <span class="bulk-select-topic-dropdown__count">
    {{i18n "topics.bulk.selected_count" count=@data.selectedCount}}
  </span>
  <BulkSelectTopicsDropdown
    @bulkSelectHelper={{@data.bulkSelectHelper}}
    @afterBulkActionComplete={{@data.afterBulkAction}}
  />
</template>;

export default class extends EmberObject {
  @service router;

  get selectedCount() {
    return this.bulkSelectHelper.selected.length;
  }

  @action
  afterBulkAction() {
    return this.router.refresh();
  }

  get html() {
    return rawRenderGlimmer(
      this,
      "div.bulk-select-topics-dropdown",
      BulkSelectGlimmerWrapper,
      {
        bulkSelectHelper: this.bulkSelectHelper,
        selectedCount: this.selectedCount,
        afterBulkAction: this.afterBulkAction,
      }
    );
  }
}
