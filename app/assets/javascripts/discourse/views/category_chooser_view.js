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
  dataAttributes: ['name', 'color', 'text_color', 'description', 'topic_count'],
  valueBinding: Ember.Binding.oneWay('source'),

  init: function() {
    this._super();
    this.set('content', Discourse.Category.list());
  },

  none: function() {
    if (Discourse.SiteSettings.allow_uncategorized_topics || this.get('showUncategorized')) return 'category.none';
  }.property('showUncategorized'),

  template: function(text, templateData) {
    if (!templateData.color) return text;
    var result = "<span class='badge-category' style='background-color: #" + templateData.color + '; color: #' +
        templateData.text_color + ";'>" + templateData.name + "</span>";
    result += " <span class='topic-count'>&times; " + templateData.topic_count + "</span>";
    if (templateData.description && templateData.description !== 'null') {
      result += '<div class="category-desc">' + templateData.description.substr(0,200) + (templateData.description.length > 200 ? '&hellip;' : '') + '</div>';
    }
    return result;
  }

});

Discourse.View.registerHelper('categoryChooser', Discourse.CategoryChooserView);