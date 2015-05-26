export default Ember.Component.extend({
  _parse: function() {
    Ember.run.next(null, () => {
      this.$().find('hr').remove();
      this.$().ellipsis();
    });
  }.on('didInsertElement'),

  render(buffer) {
    buffer.push(this.get('text'));
  }
});
