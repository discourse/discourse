window.Discourse.EditCategoryView = window.Discourse.ModalBodyView.extend
  templateName: 'modal/edit_category'
  appControllerBinding: 'Discourse.appController'

  disabled: (->
    return true if @get('saving')
    return true unless @get('category.name')
    return true unless @get('category.color')
    false
  ).property('category.name', 'category.color')

  colorStyle: (->
    "background-color: ##{@get('category.color')};"
  ).property('category.color')

  title: (->
    if @get('category.id') then "Edit Category" else "Create Category"
  ).property('category.id')

  buttonTitle: (->
    if @get('saving') then "Saving..." else @get('title')
  ).property('title', 'saving')

  didInsertElement: ->

    @._super()

    if @get('category')
      @set('id', @get('category.slug'))
    else
      @set('category', Discourse.Category.create(color: 'AB9364'))

  saveSuccess: (result) ->
    $('#discourse-modal').modal('hide')
    window.location = "/category/#{result.category.slug}"

  saveCategory: ->

    @set('saving', true)
    @get('category').save
      success: (result) => @saveSuccess(result)
      error: (errors) =>
        @displayErrors(errors)
        @set('saving', false)

