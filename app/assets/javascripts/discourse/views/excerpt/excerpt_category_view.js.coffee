window.Discourse.ExcerptCategoryView = Ember.View.extend

  editCategory: ->
    @get('parentView').close()

    # We create an attribute, id, with the old name so we can rename it.
    cat = @get('category')

    cat.set('id', cat.get('slug'))
    @get('controller.controllers.modal')?.showView(Discourse.EditCategoryView.create(category: cat))
    false

  deleteCategory: ->
    @get('parentView').close()

    bootbox.confirm Em.String.i18n("category.delete_confirm"), (result) =>
      if result
        @get('category').delete ->
          Discourse.get('appController').reloadSession -> Discourse.get('router').route("/categories")

    false

  didInsertElement: ->
    @set 'category', Discourse.Category.create
      name: @get('name')
      color: @get('color')
      slug: @get('slug')
      excerpt: @get('excerpt')
      topic_url: @get('topic_url')
