import { on } from "@ember/modifier";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BulkSelectCell = <template>
  <th class="bulk-select topic-list-data">
    {{#if @canBulkSelect}}
      <button
        {{on "click" @bulkSelectHelper.toggleBulkSelect}}
        title={{i18n "topics.bulk.toggle"}}
        class="btn-flat bulk-select"
      >
        {{icon "list-check"}}
      </button>
    {{/if}}
  </th>
</template>;

export default BulkSelectCell;
