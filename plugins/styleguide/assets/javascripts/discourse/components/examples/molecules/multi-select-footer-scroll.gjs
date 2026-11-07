import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import { i18n } from "discourse-i18n";

const ITEMS = Array.from({ length: 40 }, (_, index) => ({
  id: index + 1,
  name: `Example item ${index + 1}`,
}));

export default class MultiSelectFooterScrollExample extends Component {
  @tracked selection = [ITEMS[0]];

  @action
  async loadItems(filter) {
    const query = filter.toLowerCase();
    return ITEMS.filter((item) => item.name.toLowerCase().includes(query));
  }

  @action
  selectItems(selection) {
    this.selection = selection;
  }

  <template>
    <DMultiSelect
      @label={{i18n "styleguide.sections.multi_select.choose_item"}}
      @loadFn={{this.loadItems}}
      @onChange={{this.selectItems}}
      @selection={{this.selection}}
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
}
