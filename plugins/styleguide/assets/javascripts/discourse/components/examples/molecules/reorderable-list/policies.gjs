import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

export default class ReorderableListPoliciesExample extends Component {
  items = trackedArray([
    { id: "pinned", name: "Pinned (cannot move)", pinned: true },
    { id: "first", name: "First movable" },
    { id: "second", name: "Second movable" },
    { id: "third", name: "Third movable" },
  ]);

  itemLabel = (item) => item.name;

  movable = (item) => !item.pinned;

  @action
  applyMove({ proposedToItems }) {
    this.items.splice(0, this.items.length, ...proposedToItems);
  }

  <template>
    <DReorderableList
      @items={{this.items}}
      @key="id"
      @label={{this.itemLabel}}
      @movable={{this.movable}}
      @wrap={{true}}
      @arrowsLayout="inline"
      @controlsVisibility="reveal"
      @onMove={{this.applyMove}}
      class="styleguide-reorderable-list"
      as |item|
    >
      <span>{{item.name}}</span>
    </DReorderableList>
  </template>
}
