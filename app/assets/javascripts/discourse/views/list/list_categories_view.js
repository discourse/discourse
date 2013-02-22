(function() {

  window.Discourse.ListCategoriesView = Discourse.View.extend({
    templateName: 'list/categories',
    didInsertElement: function() {
      return Discourse.set('title', Em.String.i18n("category.list"));
    }
  });

}).call(this);
