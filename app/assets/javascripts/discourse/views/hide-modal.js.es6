export default Em.View.extend({
  // No rendering!
  render: Em.K,

  _hideModal: function() {
    $('#discourse-modal').modal('hide');
  }.on('didInsertElement')
});
