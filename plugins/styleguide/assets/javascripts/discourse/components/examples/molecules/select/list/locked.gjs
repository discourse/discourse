import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { TAGS } from "../../../../../lib/select-fixtures.js";

const HELD = ["design-system", "accessibility"];

const ListLockedExample = <template>
  <div class="select-examples__list-pair">
    <DSelectList
      class="select-examples__tag-list"
      @disabled={{true}}
      @identifier="sg-list-disabled"
      @items={{TAGS}}
      @label={{i18n "styleguide.sections.select.list_disabled_label"}}
      @labelField="label"
      @searchPlaceholder={{i18n "styleguide.sections.select.list_search"}}
      @value={{HELD}}
      @valueField="slug"
      @virtualized={{false}}
    />
    <DSelectList
      class="select-examples__tag-list"
      @identifier="sg-list-readonly"
      @items={{TAGS}}
      @label={{i18n "styleguide.sections.select.list_readonly_label"}}
      @labelField="label"
      @readonly={{true}}
      @searchPlaceholder={{i18n "styleguide.sections.select.list_search"}}
      @value={{HELD}}
      @valueField="slug"
      @virtualized={{false}}
    />
  </div>
</template>;

export default ListLockedExample;
