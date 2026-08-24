import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DButton from "discourse/ui-kit/d-button";
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
  remove(item) {
    this.items.splice(this.items.indexOf(item), 1);
  }

  <template>
    <DReorderableList
      @items={{this.items}}
      @key="id"
      @label={{this.itemLabel}}
      @onMove={{this.applyMove}}
      class="styleguide-reorderable-list"
    >
      <:row as |item|>
        <input
          {{on "input" (fn this.updateValue item)}}
          value={{item.value}}
          type="text"
          class="styleguide-reorderable-list__input"
        />
        <DButton
          @icon="xmark"
          @action={{fn this.remove item}}
          class="btn-flat btn-small"
        />
      </:row>
    </DReorderableList>
  </template>
}
