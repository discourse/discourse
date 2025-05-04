import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DMultiSelect from "discourse/components/d-multi-select";
import StyleguideComponent from "../../styleguide/component";
import StyleguideExample from "../../styleguide-example";

export default class MultiSelect extends Component {
  @tracked selection = [{ id: 1, name: "foo" }];

  @action
  onChange(selection) {
    this.selection = selection;
  }

  @action
  async loadDummyData(filter) {
    await new Promise((resolve) => setTimeout(resolve, 500));

    return [
      { id: 1, name: "foo" },
      { id: 2, name: "bar" },
      { id: 3, name: "baz" },
    ].filter((item) => {
      return item.name.toLowerCase().includes(filter.toLowerCase());
    });
  }

  <template>
    <StyleguideExample @title="<DMultiSelect />">
      <StyleguideComponent @tag="d-multi-select component">
        <:sample>
          <DMultiSelect
            @loadFn={{this.loadDummyData}}
            @onChange={{this.onChange}}
            @selection={{this.selection}}
          >
            <:result as |result|>{{result.name}}</:result>
            <:selection as |result|>{{result.name}}</:selection>
          </DMultiSelect>
        </:sample>
      </StyleguideComponent>
    </StyleguideExample>
  </template>
}
