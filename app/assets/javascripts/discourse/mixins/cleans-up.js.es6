import Mixin from '@ember/object/mixin';
// Include this mixin if you want to be notified when the dom should be
// cleaned (usually on route change.)
export default Mixin.create({
  _initializeChooser: Ember.on("didInsertElement", function() {
    this.appEvents.on("dom:clean", this, "cleanUp");
  }),

  _clearChooser: Ember.on("willDestroyElement", function() {
    this.appEvents.off("dom:clean", this, "cleanUp");
  })
});
