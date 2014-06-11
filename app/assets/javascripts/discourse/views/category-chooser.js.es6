/**
  This view handles rendering of a combobox that can view a category

  @class CategoryChooserView
  @extends Discourse.ComboboxView
  @namespace Discourse
  @module Discourse
**/
import ComboboxView from 'discourse/views/combo-box';

export default ComboboxView.extend({
  classNames: ['combobox category-combobox'],
  overrideWidths: true,
  dataAttributes: ['id', 'description_text'],
  valueBinding: Ember.Binding.oneWay('source'),

  content: Em.computed.filter('categories', function(c) {
    var uncategorized_id = Discourse.Site.currentProp("uncategorized_category_id");
    return c.get('permission') === Discourse.PermissionType.FULL && c.get('id') !== uncategorized_id;
  }),

  init: function() {
    this._super();
    if (!this.get('categories')) {
      this.set('categories', Discourse.Category.list());
    }
  },

  none: function() {
    if (Discourse.User.currentProp('staff') || Discourse.SiteSettings.allow_uncategorized_topics) {
      if (this.get('rootNone')) {
        return "category.none";
      } else {
        return Discourse.Category.list().findBy('id', Discourse.Site.currentProp('uncategorized_category_id'));
      }
    } else {
      return 'category.choose';
    }
  }.property(),

  template: function(item) {
    var category = Discourse.Category.findById(parseInt(item.id,10));
    if (!category) return item.text;

    var result = Discourse.HTML.categoryBadge(category, {showParent: true, link: false, allowUncategorized: true});

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
