export default Ember.Component.extend({
  _parse: function() {
    this.$().find('hr').remove();
    this.$().ellipsis();
  }.on('didInsertElement'),

  render: function(buffer) {
    buffer.push(this.get('text'));
  }
});
