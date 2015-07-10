import ComboboxView from 'discourse/components/combo-box';
import { categoryBadgeHTML } from 'discourse/helpers/category-link';

export default ComboboxView.extend({
  classNames: ['combobox category-combobox'],
  overrideWidths: true,
  dataAttributes: ['id', 'description_text'],
  valueBinding: Ember.Binding.oneWay('source'),
  castInteger: true,

  content: function() {
    let scopedCategoryId = this.get('scopedCategoryId');

    // Always scope to the parent of a category, if present
    if (scopedCategoryId) {
      const scopedCat = Discourse.Category.findById(scopedCategoryId);
      scopedCategoryId = scopedCat.get('parent_category_id') || scopedCat.get('id');
    }

    return this.get('categories').filter(function(c) {
      if (scopedCategoryId && (c.get('id') !== scopedCategoryId) && (c.get('parent_category_id') !== scopedCategoryId)) {
        return false;
      }
      return c.get('permission') === Discourse.PermissionType.FULL && !c.get('isUncategorizedCategory');
    });
  }.property('scopedCategoryId', 'categories'),

  _setCategories: function() {

    if (!this.get('categories')) {
      this.set('automatic', true);
    }

    this._updateCategories();

  }.on('init'),

  _updateCategories: function() {

    if (this.get('automatic')) {
      this.set('categories',
          Discourse.SiteSettings.fixed_category_positions_on_create ?
            Discourse.Category.list() : Discourse.Category.listByActivity()
      );
    }
  }.observes('automatic', 'site.sortedCategories'),

  none: function() {
    if (Discourse.User.currentProp('staff') || Discourse.SiteSettings.allow_uncategorized_topics) {
      if (this.get('rootNone')) {
        return "category.none";
      } else {
        return Discourse.Category.findUncategorized();
      }
    } else {
      return 'category.choose';
    }
  }.property(),

  comboTemplate(item) {

    let category;

    // If we have no id, but text with the uncategorized name, we can use that badge.
    if (Ember.isEmpty(item.id)) {
      const uncat = Discourse.Category.findUncategorized();
      if (uncat && uncat.get('name') === item.text) {
        category = uncat;
      }
    } else {
      category = Discourse.Category.findById(parseInt(item.id,10));
    }

    if (!category) return item.text;
    let result = categoryBadgeHTML(category, {link: false, allowUncategorized: true, hideParent: true});
    const parentCategoryId = category.get('parent_category_id');

    if (parentCategoryId) {
      result = categoryBadgeHTML(Discourse.Category.findById(parentCategoryId), {link: false}) + "&nbsp;" + result;
    }

    result += " <span class='topic-count'>&times; " + category.get('topic_count') + "</span>";

    const description = category.get('description');
    // TODO wtf how can this be null?;
    if (description && description !== 'null') {
      result += '<div class="category-desc">' +
                 description.substr(0,200) +
                 (description.length > 200 ? '&hellip;' : '') +
                 '</div>';
    }
    return result;
  }

});
