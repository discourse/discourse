export default Ember.View.extend({
  templateName: 'user/username',
  classNames: ['user-preferences'],

  _focusUsername: function() {
    Em.run.schedule('afterRender', function() {
      $('#change_username').focus();
    });
  }.on('didInsertElement'),

  keyDown: function(e) {
    if (e.keyCode === 13) {
      if (!this.get('controller').get('saveDisabled')) {
        return this.get('controller').send('changeUsername');
      } else {
        e.preventDefault();
        return false;
      }
    }
  }
});
