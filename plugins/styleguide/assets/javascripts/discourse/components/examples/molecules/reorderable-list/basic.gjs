import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

export default class ReorderableListBasicExample extends Component {
  items = trackedArray([
    { id: "inbox", name: "Inbox" },
    { id: "starred", name: "Starred" },
    { id: "drafts", name: "Drafts" },
    { id: "archive", name: "Archive" },
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
      @onMove={{this.applyMove}}
      class="styleguide-reorderable-list"
      as |item|
    >
      <span>{{item.name}}</span>
    </DReorderableList>
  </template>
}
