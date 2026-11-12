import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

export default class ReorderableListEditableExample extends Component {
  items = trackedArray([
    { id: "welcome", value: "Welcome to the community" },
    { id: "rules", value: "Read the rules first" },
    { id: "intro", value: "Introduce yourself" },
  ]);

  itemLabel = (item) => item.value;

  @action
  applyMove({ proposedToItems }) {
    this.items.splice(0, this.items.length, ...proposedToItems);
  }

  @action
  updateValue(item, event) {
    item.value = event.target.value;
  }

  @action
  remove(item, index) {
    this.items.splice(index, 1);
  }

  <template>
    <DReorderableList
      class="styleguide-reorderable-list"
      @items={{this.items}}
      @key="id"
      @label={{this.itemLabel}}
      @onMove={{this.applyMove}}
      @onRemove={{this.remove}}
    >
      <:row as |item|>
        <input
          class="styleguide-reorderable-list__input"
          type="text"
          value={{item.value}}
          {{on "input" (fn this.updateValue item)}}
        />
      </:row>
    </DReorderableList>
  </template>
}
