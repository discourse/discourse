/**
  This view handles rendering of a navigation item

  @class NavItemView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.NavItemView = Discourse.View.extend({
  tagName: 'li',
  classNameBindings: ['active', 'content.hasIcon:has-icon'],
  attributeBindings: ['title'],

  hidden: Em.computed.not('content.visible'),
  count: Ember.computed.alias('content.count'),
  shouldRerender: Discourse.View.renderIfChanged('count'),
  active: Discourse.computed.propertyEqual('content.filterMode', 'controller.filterMode'),

  title: function() {
    var categoryName = this.get('content.categoryName'),
        name = this.get('content.name'),
        extra;

    if (categoryName) {
      extra = { categoryName: categoryName };
      name = "category";
    }
    return I18n.t("filters." + name + ".help", extra);
  }.property("content.filter"),


  name: function() {
    var categoryName = this.get('content.categoryName'),
        name = this.get('content.name'),
        extra = {
          count: this.get('content.count') || 0
        };

    if (categoryName) {
      name = 'category';
      extra.categoryName = Discourse.Formatter.toTitleCase(categoryName);
    }
    return I18n.t("filters." + name + ".title", extra);
  }.property('count'),

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


