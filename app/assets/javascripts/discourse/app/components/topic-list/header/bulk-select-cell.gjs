import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const BulkSelectCell = <template>
  <th class="bulk-select topic-list-data">
    {{#if @canBulkSelect}}
      <button
        {{on "click" @bulkSelectHelper.toggleBulkSelect}}
        title={{i18n "topics.bulk.toggle"}}
        class="btn-transparent bulk-select no-text"
      >
        {{icon "list-check"}}
      </button>
    {{/if}}
  </th>
</template>;

export default BulkSelectCell;
