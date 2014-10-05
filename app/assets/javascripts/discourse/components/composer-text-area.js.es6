export default Ember.TextArea.extend({
  elementId: 'wmd-input',

  placeholder: function() {
    return I18n.t('composer.reply_placeholder');
  }.property('placeholderKey'),

  _signalParentInsert: function() {
    return this.get('parentView').childDidInsertElement(this);
  }.on('didInsertElement'),

  _signalParentDestroy: function() {
    return this.get('parentView').childWillDestroyElement(this);
  }.on('willDestroyElement')
});

