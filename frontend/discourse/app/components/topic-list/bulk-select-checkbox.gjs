import { on } from "@ember/modifier";

const BulkSelectCheckbox = <template>
  <label for="bulk-select-{{@topic.id}}" ...attributes>
    <input
      checked={{@isSelected}}
      class="bulk-select"
      id="bulk-select-{{@topic.id}}"
      type="checkbox"
      {{on "click" @onToggle}}
    />
  </label>
</template>;

export default BulkSelectCheckbox;
