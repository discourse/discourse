export default Ember.Component.extend({
  _parse: function() {
    this.$().ellipsis();
  }.on('didInsertElement'),

  render: function(buffer) {
    buffer.push(this.get('text'));
  }
});
