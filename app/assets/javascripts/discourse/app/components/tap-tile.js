import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  init() {
    this._super(...arguments);
    this.set("elementId", `tap_tile_${this.tileId}`);
  },
  classNames: ["tap-tile"],
  classNameBindings: ["active"],
  click() {
    this.onChange(this.tileId);
  },

  active: propertyEqual("activeTile", "tileId")
});
