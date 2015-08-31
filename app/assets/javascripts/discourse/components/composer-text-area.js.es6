export default Ember.TextArea.extend({
  classNameBindings: [':wmd-input'],

  placeholder: function() {
    return I18n.t('composer.reply_placeholder');
  }.property('placeholderKey'),

  _signalParentInsert: function() {
    this.get('parentView').childDidInsertElement(this);
  }.on('didInsertElement'),

  _signalParentDestroy: function() {
    this.get('parentView').childWillDestroyElement(this);
  }.on('willDestroyElement')
});
