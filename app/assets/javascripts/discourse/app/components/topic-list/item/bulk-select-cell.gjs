import { on } from "@ember/modifier";

const BulkSelectCell = <template>
  <td class="bulk-select topic-list-data">
    <label for="bulk-select-{{@topic.id}}">
      <input
        {{on "click" @onBulkSelectToggle}}
        checked={{@isSelected}}
        type="checkbox"
        id="bulk-select-{{@topic.id}}"
        class="bulk-select"
      />
    </label>
  </td>
</template>;

export default BulkSelectCell;
