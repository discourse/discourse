import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class ReorderableListTogglesExample extends Component {
  items = trackedArray([
    { id: "summary", name: "Summary", enabled: true },
    { id: "activity", name: "Activity", enabled: true },
    { id: "storage", name: "Storage", enabled: true },
    { id: "backups", name: "Backups", enabled: false },
    { id: "security", name: "Security", enabled: false },
  ]);

  isEnabled = (item) => item.enabled;
  itemLabel = (item) => item.name;

  @action
  applyMove({ proposedToItems }) {
    this.items.splice(0, this.items.length, ...proposedToItems);
  }

  @action
  toggle(item) {
    const next = { ...item, enabled: !item.enabled };
    const rest = this.items.filter((candidate) => candidate !== item);
    const enabled = rest.filter((candidate) => candidate.enabled);
    const disabled = rest.filter((candidate) => !candidate.enabled);
    const reordered = next.enabled
      ? [...enabled, next, ...disabled]
      : [...enabled, ...disabled, next];
    this.items.splice(0, this.items.length, ...reordered);
  }

  <template>
    <DReorderableList
      @items={{this.items}}
      @key="id"
      @label={{this.itemLabel}}
      @movable={{this.isEnabled}}
      @onMove={{this.applyMove}}
      class="styleguide-reorderable-list"
    >
      <:row as |item|>
        <span
          class={{dConcatClass
            "styleguide-reorderable-list__label"
            (unless item.enabled "--static")
          }}
        >{{item.name}}</span>
        <DToggleSwitch
          @state={{item.enabled}}
          {{on "click" (fn this.toggle item)}}
        />
      </:row>
    </DReorderableList>
  </template>
}
