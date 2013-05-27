/**
  This view handles rendering of a navigation item

  @class NavItemView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.NavItemView = Discourse.View.extend({
  tagName: 'li',
  classNameBindings: ['isActive', 'content.hasIcon:has-icon'],
  attributeBindings: ['title'],
  countBinding: Ember.Binding.oneWay('content.count'),

  title: function() {
    var categoryName, extra, name;
    name = this.get('content.name');
    categoryName = this.get('content.categoryName');
    if (categoryName) {
      extra = { categoryName: categoryName };
      name = "category";
    }
    return Ember.String.i18n("filters." + name + ".help", extra);
  }.property("content.filter"),

  isActive: function() {
    if (this.get("content.name").replace(' ','-') === this.get("controller.filterMode")) return "active";
    return "";
  }.property("content.name", "controller.filterMode"),

  hidden: Em.computed.not('content.visible'),

  countChanged: function(){
    this.rerender();
  }.observes('count'),

  name: function() {
    var categoryName, extra, name;
    name = this.get('content.name');
    categoryName = this.get('content.categoryName');
    extra = {
      count: this.get('content.count') || 0
    };
    if (categoryName) {
      name = 'category';
      extra.categoryName = categoryName.titleize();
    }
    return I18n.t("js.filters." + name + ".title", extra);
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


