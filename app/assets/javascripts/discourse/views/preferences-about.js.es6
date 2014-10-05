export default Ember.View.extend({
  templateName: 'user/about',
  classNames: ['user-preferences'],

  _focusAbout: function() {
    var self = this;
    Ember.run.schedule('afterRender', function() {
      self.$('textarea').focus();
    });
  }.on('didInsertElement')
});
