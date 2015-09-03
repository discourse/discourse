import DiscourseURL from 'discourse/lib/url';
import { buildCategoryPanel } from 'discourse/components/edit-category-panel';
import { categoryBadgeHTML } from 'discourse/helpers/category-link';
import Category from 'discourse/models/category';

export default buildCategoryPanel('general', {
  foregroundColors: ['FFFFFF', '000000'],
  canSelectParentCategory: Em.computed.not('category.isUncategorizedCategory'),

  // background colors are available as a pipe-separated string
  backgroundColors: function() {
    const categories = Discourse.Category.list();
    return this.siteSettings.category_colors.split("|").map(function(i) { return i.toUpperCase(); }).concat(
                categories.map(function(c) { return c.color.toUpperCase(); }) ).uniq();
  }.property(),

  usedBackgroundColors: function() {
    const categories = Discourse.Category.list();
    const category = this.get('category');

    // If editing a category, don't include its color:
    return categories.map(function(c) {
      return (category.get('id') && category.get('color').toUpperCase() === c.color.toUpperCase()) ? null : c.color.toUpperCase();
    }, this).compact();
  }.property('category.id', 'category.color'),

  parentCategories: function() {
    return Discourse.Category.list().filter(function (c) {
      return !c.get('parentCategory');
    });
  }.property(),

  categoryBadgePreview: function() {
    const category = this.get('category');
    const c = Category.create({
      name: category.get('categoryName'),
      color: category.get('color'),
      text_color: category.get('text_color'),
      parent_category_id: parseInt(category.get('parent_category_id'),10),
      read_restricted: category.get('read_restricted')
    });
    return categoryBadgeHTML(c, {link: false});
  }.property('category.parent_category_id', 'category.categoryName', 'category.color', 'category.text_color'),


  // We can change the parent if there are no children
  subCategories: function() {
    if (Ember.isEmpty(this.get('category.id'))) { return null; }
    return Category.list().filterBy('parent_category_id', this.get('category.id'));
  }.property('category.id'),

  showDescription: function() {
    return !this.get('category.isUncategorizedCategory') && this.get('category.id');
  }.property('category.isUncategorizedCategory', 'category.id'),

  actions: {
    showCategoryTopic() {
      DiscourseURL.routeTo(this.get('category.topic_url'));
      return false;
    }
  }
});
