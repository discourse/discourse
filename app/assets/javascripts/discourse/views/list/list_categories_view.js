(function() {

  window.Discourse.ListCategoriesView = Ember.View.extend({
    templateName: 'list/categories',
    didInsertElement: function() {
      return Discourse.set('title', Em.String.i18n("category.list"));
    }
  });

}).call(this);
