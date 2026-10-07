import BulkSelectCheckbox from "discourse/components/topic-list/bulk-select-checkbox";

const BulkSelectCell = <template>
  <td class="bulk-select topic-list-data">
    <BulkSelectCheckbox
      @isSelected={{@isSelected}}
      @onToggle={{@onBulkSelectToggle}}
      @topic={{@topic}}
    />
  </td>
</template>;

export default BulkSelectCell;
