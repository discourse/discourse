/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { computed } from "@ember/object";
import {
  attributeBindings,
  classNameBindings,
  classNames,
} from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { deepEqual } from "discourse/lib/object";

@classNames("tap-tile")
@classNameBindings("active")
@attributeBindings("role", "ariaPressed", "tabIndex")
export default class TapTile extends Component {
  role = "button";
  tabIndex = 0;

  @tracked _ariaPressedOverride;

  init() {
    super.init(...arguments);
    this.set("elementId", `tap_tile_${this.tileId}`);
  }

  @computed("active")
  get ariaPressed() {
    if (this._ariaPressedOverride !== undefined) {
      return this._ariaPressedOverride;
    }
    return this.active;
  }

  set ariaPressed(value) {
    this._ariaPressedOverride = value;
  }

  @computed("activeTile", "tileId")
  get active() {
    return deepEqual(this.activeTile, this.tileId);
  }

  click() {
    this.onChange(this.tileId);
  }

  keyDown(e) {
    if (e.key === "Enter") {
      e.stopPropagation();
      this.onChange(this.tileId);
    }
  }

  <template>
    {{#if this.icon}}
      {{icon this.icon}}
    {{/if}}
    {{yield}}
  </template>
}
