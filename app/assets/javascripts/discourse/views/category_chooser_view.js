/**
  This view handles rendering of a combobox that can view a category

  @class CategoryChooserView
  @extends Discourse.ComboboxView
  @namespace Discourse
  @module Discourse
**/
Discourse.CategoryChooserView = Discourse.ComboboxView.extend({
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

  template: function(text, templateData) {
    var category = Discourse.Category.findById(parseInt(templateData.id,10));
    if (!category) return text;

    var result = Discourse.HTML.categoryBadge(category, {showParent: true, link: false});

    result += " <div class='topic-count'>&times; " + category.get('topic_count') + "</div>";

    var description = templateData.description_text;
    // TODO wtf how can this be null?
    if (description && description !== 'null') {

      result += '<div class="category-desc">' +
                 description.substr(0,200) +
                 (description.length > 200 ? '&hellip;' : '') +
                 '</div>';
    }
    return result;
  }

});

Discourse.View.registerHelper('categoryChooser', Discourse.CategoryChooserView);
