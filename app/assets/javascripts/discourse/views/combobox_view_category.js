/**
  This view handles rendering of a combobox that can view a category

  @class ComboboxViewCategory
  @extends Discourse.ComboboxView
  @namespace Discourse
  @module Discourse
**/
Discourse.ComboboxViewCategory = Discourse.ComboboxView.extend({
  none: 'category.none',
  classNames: ['combobox category-combobox'],
  overrideWidths: true,
  dataAttributes: ['name', 'color', 'text_color', 'description', 'topic_count'],
  valueBinding: Ember.Binding.oneWay('source'),

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


