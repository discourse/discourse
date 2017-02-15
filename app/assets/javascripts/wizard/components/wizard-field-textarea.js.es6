export default Ember.Component.extend({
  keyPress(e) {
    e.stopPropagation();
  }
});
