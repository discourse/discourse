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
      @items={{this.values}}
      @key={{this.indexKey}}
      @label={{this.valueLabel}}
      @allowCreate={{true}}
      @onCreate={{this.addValue}}
      @onMove={{this.applyMove}}
      class="styleguide-reorderable-list"
      as |value|
    >
      <span>{{value}}</span>
    </DReorderableList>
  </template>
}
