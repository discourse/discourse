import { on } from "@ember/object/evented";
import Mixin from "@ember/object/mixin";

// Include this mixin if you want to be notified when the dom should be
// cleaned (usually on route change.)
export default Mixin.create({
  _initializeChooser: on("didInsertElement", function() {
    this.appEvents.on("dom:clean", this, "cleanUp");
  }),

  _clearChooser: on("willDestroyElement", function() {
    this.appEvents.off("dom:clean", this, "cleanUp");
  })
});
