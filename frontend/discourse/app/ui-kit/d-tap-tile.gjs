import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { deepEqual } from "discourse/lib/object";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DTapTile extends Component {
  get active() {
    return deepEqual(this.args.activeTile, this.args.tileId);
  }

  @action
  click() {
    this.args.onChange(this.args.tileId);
  }

  @action
  keyDown(e) {
    if (e.key === "Enter") {
      e.stopPropagation();
      this.args.onChange(this.args.tileId);
    }
  }

  <template>
    <div
      role="button"
      tabindex="0"
      ...attributes
      aria-pressed={{if this.active "true" "false"}}
      class={{dConcatClass "tap-tile" (if this.active "active")}}
      id="tap_tile_{{@tileId}}"
      {{on "click" this.click}}
      {{on "keydown" this.keyDown}}
    >
      {{#if @icon}}
        {{dIcon @icon}}
      {{/if}}
      {{yield}}
    </div>
  </template>
}
