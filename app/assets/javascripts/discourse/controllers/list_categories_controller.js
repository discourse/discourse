/**
  This controller supports actions when listing categories

  @class ListCategoriesController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.ListCategoriesController = Discourse.ObjectController.extend({
  needs: ['modal'],

  actions: {
    toggleOrdering: function(){
      this.set("ordering",!this.get("ordering"));
    }
  },

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
    return Discourse.User.currentProp('staff');
  }.property(),

  // clear a pinned topic
  clearPin: function(topic) {
    topic.clearPin();
  },

  moveCategory: function(categoryId, position){
    this.get('model.categories').moveCategory(categoryId, position);
  }

});


