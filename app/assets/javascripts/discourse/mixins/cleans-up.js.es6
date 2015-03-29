// Include this mixin if you want to be notified when the dom should be
// cleaned (usually on route change.)
export default Ember.Mixin.create({
  _initializeChooser: function() {
    this.appEvents.on('dom:clean', this, "cleanUp");
  }.on('didInsertElement'),

  _clearChooser: function() {
    this.appEvents.off('dom:clean', this, "cleanUp");
  }.on('willDestroyElement')
});
