import DButton from "discourse/ui-kit/d-button";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import { i18n } from "discourse-i18n";

const loadItems = async () => [];

export default <template>
  <DMultiSelect
    @label={{i18n "styleguide.sections.multi_select.choose_item"}}
    @loadFn={{loadItems}}
  >
    <:result as |item|>{{item.name}}</:result>
    <:selection as |item|>{{item.name}}</:selection>
    <:footer as |menu|>
      <DButton
        @action={{menu.close}}
        @icon="plus"
        @label="styleguide.sections.multi_select.create_item"
      />
    </:footer>
  </DMultiSelect>
</template>
