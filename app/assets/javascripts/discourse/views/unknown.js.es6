export default Em.View.extend({
  classNameBindings: [':container'],

  render: function(buffer) {
    buffer.push(this.get('controller.model'));
  }
});
