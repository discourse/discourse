import { fmt } from "discourse/lib/computed";

export default Ember.Component.extend({
  panel: null,

  panelComponent: fmt("panel.id", "%@-panel"),

  classNameBindings: ["panel.id"],

  classNames: ["modal-panel"]
});
