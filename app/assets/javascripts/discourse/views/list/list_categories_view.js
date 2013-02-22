/**
  This view handles the rendering of a category list

  @class ListCategoriesView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
window.Discourse.ListCategoriesView = Discourse.View.extend({

  templateName: 'list/categories',

  didInsertElement: function() {
    return Discourse.set('title', Em.String.i18n("category.list"));
  }

});


