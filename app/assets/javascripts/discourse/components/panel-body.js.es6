import { default as computed } from "ember-addons/ember-computed-decorators";
import { fmt } from "discourse/lib/computed";

export default Ember.Component.extend({
  panel: null,

  panelBodyComponent: fmt("panel.id", "%@-panel"),

  classNames: ["panel-body"]
});
