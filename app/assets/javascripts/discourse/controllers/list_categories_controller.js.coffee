Discourse.ListCategoriesController = Ember.ObjectController.extend Discourse.Presence,
  needs: ['modal']

  categoriesEven: (->
    return Em.A() if @blank('categories')
    @get('categories').filter (item, index) -> (index % 2) == 0
  ).property('categories.@each')

  categoriesOdd: (->
    return Em.A() if @blank('categories')
    @get('categories').filter (item, index) -> (index % 2) == 1
  ).property('categories.@each')

  editCategory: (category) ->
    @get('controllers.modal').show(Discourse.EditCategoryView.create(category: category))
    false
  
  canEdit: (->
    u = Discourse.get('currentUser')
    u && u.admin
  ).property()
