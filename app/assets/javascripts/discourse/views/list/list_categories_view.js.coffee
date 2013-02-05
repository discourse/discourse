window.Discourse.ListCategoriesView = Ember.View.extend
  templateName: 'list/categories'

  didInsertElement: ->
    Discourse.set('title', Em.String.i18n("category.list"))
