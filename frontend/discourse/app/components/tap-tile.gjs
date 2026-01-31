/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { reads } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { propertyEqual } from "discourse/lib/computed";

@tagName("")
export default class TapTile extends Component {
  role = "button";
  tabIndex = 0;

  @reads("active") ariaPressed;
  @propertyEqual("activeTile", "tileId") active;

  init() {
    super.init(...arguments);
    this.set("elementId", `tap_tile_${this.tileId}`);
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
    <div
      role={{this.role}}
      tabindex={{this.tabIndex}}
      aria-pressed={{this.ariaPressed}}
      class={{concatClass "tap-tile" (if this.active "active")}}
      ...attributes
    >
      {{#if this.icon}}
        {{icon this.icon}}
      {{/if}}
      {{yield}}
    </div>
  </template>
}
