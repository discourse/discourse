import { on } from "@ember/modifier";

const BulkSelectCheckbox = <template>
  <label for="bulk-select-{{@topic.id}}" ...attributes>
    <input
      {{on "click" @onToggle}}
      checked={{@isSelected}}
      type="checkbox"
      id="bulk-select-{{@topic.id}}"
      class="bulk-select"
    />
  </label>
</template>;

export default BulkSelectCheckbox;
