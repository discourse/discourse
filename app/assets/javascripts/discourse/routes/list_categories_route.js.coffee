window.Discourse.ListCategoriesRoute = Discourse.Route.extend
  exit: ->
    @_super()
    @controllerFor('list').set('canCreateCategory', false)

  setupController: (controller) ->
    listController = @controllerFor('list')
    listController.set('filterMode', 'categories')
    listController.load('categories').then (categoryList) =>
      @render 'listCategories', into: 'list', outlet: 'listView', controller: 'listCategories'
      listController.set('canCreateCategory', categoryList.get('can_create_category'))
      listController.set('category', null)
      @controllerFor('listCategories').set('content', categoryList)
