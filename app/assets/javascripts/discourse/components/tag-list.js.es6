export default Ember.Component.extend({
  classNameBindings: [':tag-list', 'categoryClass'],

  sortedTags: Ember.computed.sort('tags', 'sortProperties'),

  title: function() {
    if (this.get('titleKey')) { return I18n.t(this.get('titleKey')); }
  }.property('titleKey'),

  category: function() {
    if (this.get('categoryId')) {
      return Discourse.Category.findById(this.get('categoryId'));
    }
  }.property('categoryId'),

  categoryClass: function() {
    if (this.get('category')) {
      return "tag-list-" + this.get('category.fullSlug');
    }
  }.property('category')
});
