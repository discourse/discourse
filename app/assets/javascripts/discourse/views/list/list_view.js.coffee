window.Discourse.ListView = Ember.View.extend
  templateName: 'list/list'
  composeViewBinding: Ember.Binding.oneWay('Discourse.composeView')
  categoriesBinding: 'Discourse.site.categories'
  
  # The window has been scrolled
  scrolled: (e) -> 
    currentView = @get('container.currentView')
    currentView?.scrolled?(e)    

  createTopicText: (->
    if @get('controller.category.name')
      Em.String.i18n("topic.create_in", categoryName: @get('controller.category.name'))
    else
      Em.String.i18n("topic.create")
  ).property('controller.category.name')