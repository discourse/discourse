export default Ember.Component.extend({
  tagName: 'h2',

  _shouldRerender: Discourse.View.renderIfChanged('period.title'),
  render: function(buffer) {
    buffer.push("<i class='fa fa-calendar-o'></i> " + this.get('period.title'));
  }
});
