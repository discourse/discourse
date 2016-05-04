export default  Ember.Component.extend({
  tagName: 'a',
  classNameBindings: [':discourse-tag', 'style', 'tagClass'],
  attributeBindings: ['href'],

  tagClass: function() {
    return "tag-" + this.get('tagRecord.id');
  }.property('tagRecord.id'),

  href: function() {
    return '/tags/' + this.get('tagRecord.id');
  }.property('tagRecord.id'),
});
