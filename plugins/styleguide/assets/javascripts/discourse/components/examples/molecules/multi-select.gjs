import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DMultiSelect from "discourse/ui-kit/d-multi-select";

const ITEMS = [
  { id: 1, name: "foo" },
  { id: 2, name: "bar" },
  { id: 3, name: "baz" },
];

export default class MultiSelectExample extends Component {
  @tracked selection = [ITEMS[0]];

  @action
  async load(filter) {
    await new Promise((resolve) => setTimeout(resolve, 500));

    return ITEMS.filter((item) =>
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  onChange(selection) {
    this.selection = selection;
  }

  <template>
    <DMultiSelect
      @loadFn={{this.load}}
      @onChange={{this.onChange}}
      @selection={{this.selection}}
    >
      <:result as |result|>{{result.name}}</:result>
      <:selection as |result|>{{result.name}}</:selection>
    </DMultiSelect>
  </template>
}
