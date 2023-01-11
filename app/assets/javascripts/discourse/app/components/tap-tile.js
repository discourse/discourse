import { reads } from "@ember/object/computed";
import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  init() {
    this._super(...arguments);
    this.set("elementId", `tap_tile_${this.tileId}`);
  },

  classNames: ["tap-tile"],
  classNameBindings: ["active"],
  attributeBindings: ["role", "ariaPressed", "tabIndex"],
  role: "button",
  tabIndex: 0,
  ariaPressed: reads("active"),

  click() {
    this.onChange(this.tileId);
  },

  keyDown(e) {
    if (e.key === "Enter") {
      this.onChange(this.tileId);
    }
  },

  active: propertyEqual("activeTile", "tileId"),
});
