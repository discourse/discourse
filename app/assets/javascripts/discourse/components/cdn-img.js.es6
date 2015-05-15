export default Ember.Component.extend({
  tagName: 'img',
  attributeBindings: ['cdnSrc:src'],

  cdnSrc: function() {
    return Discourse.getURLWithCDN(this.get('src'));
  }.property('src')
});
