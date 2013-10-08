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
  dataAttributes: ['name', 'color', 'text_color', 'description_text', 'topic_count'],
  valueBinding: Ember.Binding.oneWay('source'),

  init: function() {
    this._super();
    // TODO perhaps allow passing a param in to select if we need full or not
    this.set('content', _.filter(Discourse.Category.list(), function(c){
      return c.permission === Discourse.PermissionType.FULL;
    }));
  },

  none: function() {
    if (!Discourse.SiteSettings.allow_uncategorized_topics) {
      return 'category.choose';
    } else if (Discourse.SiteSettings.allow_uncategorized_topics || this.get('showUncategorized')) {
      return 'category.none';
    }
  }.property('showUncategorized'),

  template: function(text, templateData) {
    if (!templateData.color) return text;

    var result = "<div class='badge-category' style='background-color: #" + templateData.color + '; color: #' +
        templateData.text_color + ";'>" + templateData.name + "</div>";

    result += " <div class='topic-count'>&times; " + templateData.topic_count + "</div>";

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
