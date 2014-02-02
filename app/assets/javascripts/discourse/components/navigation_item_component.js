/**
  This view handles rendering of a navigation item

  @class NavigationItemComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.NavigationItemComponent = Ember.Component.extend({
  tagName: 'li',
  classNameBindings: ['active', 'content.hasIcon:has-icon'],
  attributeBindings: ['title'],
  hidden: Em.computed.not('content.visible'),
  shouldRerender: Discourse.View.renderIfChanged('content.count'),

  title: function() {
    var categoryName = this.get('content.categoryName'),
        name = this.get('content.name'),
        extra;

    if (categoryName) {
      extra = { categoryName: categoryName };
      name = "category";
    }
    return I18n.t("filters." + name + ".help", extra);
  }.property("content.name"),

  active: function() {
    return this.get('content.filterMode') === this.get('filterMode') ||
           this.get('filterMode').indexOf(this.get('content.filterMode')) === 0;
  }.property('content.filterMode', 'filterMode'),

  name: function() {
    var categoryName = this.get('content.categoryName'),
        name = this.get('content.name'),
        extra = { count: this.get('content.count') || 0 };

    if (categoryName) {
      name = 'category';
      extra.categoryName = Discourse.Formatter.toTitleCase(categoryName);
    }
    return I18n.t("filters." + name + ".title", extra);
  }.property('content.count'),

  render: function(buffer) {
    var content = this.get('content');
    buffer.push("<a href='" + content.get('href') + "'>");
    if (content.get('hasIcon')) {
      buffer.push("<span class='" + content.get('name') + "'></span>");
    }
    buffer.push(this.get('name'));
    buffer.push("</a>");
  }
});
