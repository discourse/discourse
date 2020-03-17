import Component from "@ember/component";
import { fmt } from "discourse/lib/computed";

export default Component.extend({
  panel: null,

  panelComponent: fmt("panel.id", "%@-panel"),

  classNameBindings: ["panel.id"],

  classNames: ["modal-panel"]
});
