import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

export default class ReorderableListCreateExample extends Component {
  values = trackedArray(["apples", "bananas", "cherries"]);

  indexKey = "@index";

  valueLabel = (value) => value;

  @action
  applyMove({ proposedToItems }) {
    this.values.splice(0, this.values.length, ...proposedToItems);
  }

  @action
  addValue(value) {
    this.values.push(value);
  }

  <template>
    <DReorderableList
      class="styleguide-reorderable-list"
      @allowCreate={{true}}
      @items={{this.values}}
      @key={{this.indexKey}}
      @label={{this.valueLabel}}
      @onCreate={{this.addValue}}
      @onMove={{this.applyMove}}
    >
      <:row as |value|>
        <span>{{value}}</span>
      </:row>
    </DReorderableList>
  </template>
}
