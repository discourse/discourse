import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";

export default class ReorderableListPoliciesExample extends Component {
  items = trackedArray([
    { id: "announcements", name: "Announcements", pinned: true },
    { id: "latest", name: "Latest" },
    { id: "categories", name: "Categories", required: true },
    { id: "top", name: "Top" },
    { id: "bookmarks", name: "Bookmarks", pinned: true },
  ]);

  itemLabel = (item) => item.name;

  movable = (item) => !item.pinned;
  removable = (item) => !item.required;

  @action
  applyMove({ proposedToItems }) {
    this.items.splice(0, this.items.length, ...proposedToItems);
  }

  @action
  remove(item, index) {
    this.items.splice(index, 1);
  }

  <template>
    <DReorderableList
      @items={{this.items}}
      @key="id"
      @label={{this.itemLabel}}
      @movable={{this.movable}}
      @onMove={{this.applyMove}}
      @onRemove={{this.remove}}
      @removable={{this.removable}}
      class="styleguide-reorderable-list"
    >
      <:row as |item|>
        <span class="styleguide-reorderable-list__label">{{item.name}}</span>
        {{#if item.pinned}}
          <span class="styleguide-reorderable-list__note">Pinned</span>
        {{else if item.required}}
          <span class="styleguide-reorderable-list__note">Required</span>
        {{/if}}
      </:row>
    </DReorderableList>
  </template>
}
