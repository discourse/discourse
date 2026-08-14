import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

export default class ReorderableListButtonsExample extends Component {
  items = trackedArray([
    { id: "monday", name: "Monday" },
    { id: "tuesday", name: "Tuesday" },
    { id: "wednesday", name: "Wednesday" },
    { id: "thursday", name: "Thursday" },
  ]);

  itemLabel = (item) => item.name;

  @action
  applyMove({ proposedToItems }) {
    this.items.splice(0, this.items.length, ...proposedToItems);
  }

  <template>
    <DReorderableList
      @items={{this.items}}
      @key="id"
      @label={{this.itemLabel}}
      @keyboard="buttons"
      @onMove={{this.applyMove}}
      class="styleguide-reorderable-list"
      as |item|
    >
      <span>{{item.name}}</span>
    </DReorderableList>
  </template>
}
