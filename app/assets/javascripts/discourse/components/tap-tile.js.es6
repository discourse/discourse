import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  classNames: ["tap-tile"],
  classNameBindings: ["active"],
  click() {
    this.onChange(this.tileId);
  },

  active: propertyEqual("activeTile", "tileId")
});
