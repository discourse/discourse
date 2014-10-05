export default Em.View.extend({
  templateName: 'user/email',
  classNames: ['user-preferences'],
  _focusField: function() {
    Em.run.schedule('afterRender', function() {
      $('#change_email').focus();
    });
  }.on('didInsertElement')
});
