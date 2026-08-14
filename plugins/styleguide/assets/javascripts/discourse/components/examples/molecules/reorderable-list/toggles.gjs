import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

export default class ReorderableListTogglesExample extends Component {
  enabled = trackedArray([
    { id: "summary", name: "Summary" },
    { id: "activity", name: "Activity" },
    { id: "storage", name: "Storage" },
  ]);

  disabled = trackedArray([
    { id: "backups", name: "Backups" },
    { id: "security", name: "Security" },
  ]);

  itemLabel = (item) => item.name;

  @action
  applyMove({ proposedToItems }) {
    this.enabled.splice(0, this.enabled.length, ...proposedToItems);
  }

  @action
  toggle(item) {
    const from = this.enabled.includes(item) ? this.enabled : this.disabled;
    const to = from === this.enabled ? this.disabled : this.enabled;
    from.splice(from.indexOf(item), 1);
    to.push(item);
  }

  <template>
    <DReorderableList
      @items={{this.enabled}}
      @key="id"
      @label={{this.itemLabel}}
      @onMove={{this.applyMove}}
      class="styleguide-reorderable-list"
    >
      <:default as |item|>
        <span class="styleguide-reorderable-list__label">{{item.name}}</span>
        <DToggleSwitch @state={{true}} {{on "click" (fn this.toggle item)}} />
      </:default>
      <:static>
        {{#each this.disabled key="id" as |item|}}
          <li class="d-reorderable-list__row" data-reorderable-key={{item.id}}>
            <span
              class="styleguide-reorderable-list__label --static"
            >{{item.name}}</span>
            <DToggleSwitch
              @state={{false}}
              {{on "click" (fn this.toggle item)}}
            />
          </li>
        {{/each}}
      </:static>
    </DReorderableList>
  </template>
}
