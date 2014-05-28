export default Ember.TextArea.extend({
  placeholder: function() {
    return I18n.t(this.get('placeholderKey'));
  }.property('placeholderKey'),

  _signalParentInsert: function() {
    return this.get('parentView').childDidInsertElement(this);
  }.on('didInsertElement'),

  _signalParentDestroy: function() {
    return this.get('parentView').childWillDestroyElement(this);
  }.on('willDestroyElement')
});

