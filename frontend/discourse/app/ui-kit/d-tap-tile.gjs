/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { reads } from "@ember/object/computed";
import {
  attributeBindings,
  classNameBindings,
  classNames,
} from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("tap-tile")
@classNameBindings("active")
@attributeBindings("role", "ariaPressed", "tabIndex")
export default class DTapTile extends Component {
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
    {{#if this.icon}}
      {{dIcon this.icon}}
    {{/if}}
    {{yield}}
  </template>
}
