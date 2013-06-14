/**
  This controller supports actions when listing categories

  @class ListCategoriesController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoriesController = Discourse.ObjectController.extend({
  needs: ['modal'],

  categoriesEven: function() {
    if (this.blank('categories')) return Em.A();

    return this.get('categories').filter(function(item, index) {
      return (index % 2) === 0;
    });
  }.property('categories.@each'),

  categoriesOdd: function() {
    if (this.blank('categories')) return Em.A();
    return this.get('categories').filter(function(item, index) {
      return (index % 2) === 1;
    });
  }.property('categories.@each'),

  canEdit: function() {
    var u = Discourse.User.current();
    return u && u.admin;
  }.property(),

  // clear a pinned topic
  clearPin: function(topic) {
    topic.clearPin();
  }

});


