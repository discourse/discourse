import ComboboxView from 'discourse/views/combo-box';

var badgeHtml = Discourse.HTML.categoryBadge;

export default ComboboxView.extend({
  classNames: ['combobox category-combobox'],
  overrideWidths: true,
  dataAttributes: ['id', 'description_text'],
  valueBinding: Ember.Binding.oneWay('source'),

  content: function() {
    var scopedCategoryId = this.get('scopedCategoryId');

    // Always scope to the parent of a category, if present
    if (scopedCategoryId) {
      var scopedCat = Discourse.Category.findById(scopedCategoryId);
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
    this.set('categories', this.get('categories') || Discourse.Category.list());
  }.on('init'),

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

  template: function(item) {

    var category;

    // If we have no id, but text with the uncategorized name, we can use that badge.
    if (Em.empty(item.id)) {
      var uncat = Discourse.Category.findUncategorized();
      if (uncat && uncat.get('name') === item.text) {
        category = uncat;
      }
    } else {
      category = Discourse.Category.findById(parseInt(item.id,10));
    }

    if (!category) return item.text;
    var result = badgeHtml(category, {showParent: false, link: false, allowUncategorized: true}),
        parentCategoryId = category.get('parent_category_id');
    if (parentCategoryId) {
      result = badgeHtml(Discourse.Category.findById(parentCategoryId), {link: false}) + "&nbsp;" + result;
    }

    result += " <span class='topic-count'>&times; " + category.get('topic_count') + "</span>";

    var description = category.get('description');
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
