import LoadingSpinner from 'discourse/views/loading'

export default Em.View.extend({
  classNameBindings: [':container'],

  render: function(buffer) {
    var model = this.get('controller.model');
    if (!model) {
      LoadingSpinner.create({}).render(buffer);
    } else {
      buffer.push(model);
    }
  }
});
