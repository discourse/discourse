import { on } from "@ember/modifier";

const BulkSelectCell = <template>
  {{#if @bulkSelectEnabled}}
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
  {{/if}}
</template>;

export default BulkSelectCell;
