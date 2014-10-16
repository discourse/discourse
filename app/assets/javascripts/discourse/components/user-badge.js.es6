export default Ember.Component.extend({
  tagName: 'span',

  showGrantCount: function() {
    return this.get('count') && this.get('count') > 1;
  }.property('count')
});
