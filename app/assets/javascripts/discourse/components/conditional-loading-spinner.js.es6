export default Ember.Component.extend({
  classNameBindings: ['containerClass'],
  layoutName: 'components/conditional-loading-spinner',

  containerClass: function() {
    return (this.get('size') === 'small') ? 'inline-spinner' : undefined;
  }.property('size')
});
