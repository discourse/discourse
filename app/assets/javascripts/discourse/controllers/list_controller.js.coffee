Discourse.ListController = Ember.Controller.extend Discourse.Presence,
  currentUserBinding: 'Discourse.currentUser'
  categoriesBinding: 'Discourse.site.categories'
  categoryBinding: 'topicList.category'

  canCreateCategory: false
  canCreateTopic: false

  needs: ['composer', 'modal', 'listTopics']

  availableNavItems: (->
    summary = @get('filterSummary')
    loggedOn = !!Discourse.get('currentUser')
    hasCategories = !!@get('categories')

    Discourse.SiteSettings.top_menu.split("|").map((i)->
      Discourse.NavItem.fromText i,
        loggedOn: loggedOn
        hasCategories: hasCategories
        countSummary: summary
    ).filter((i)-> i != null)

  ).property('filterSummary')

  load: (filterMode) ->
    @set('loading', true)
    if filterMode == 'categories'
      return Ember.Deferred.promise (deferred) =>
        Discourse.CategoryList.list(filterMode).then (items) =>
          @set('loading', false)
          @set('filterMode', filterMode)
          @set('categoryMode', true)
          deferred.resolve(items)
    else
      current = (@get('availableNavItems').filter (f)=> f.name == filterMode)[0]
      current = Discourse.NavItem.create(name: filterMode) unless current

      return Ember.Deferred.promise (deferred) =>
        Discourse.TopicList.list(current).then (items) =>
          @set('filterSummary', items.filter_summary)
          @set('filterMode', filterMode)
          @set('allLoaded', true) unless items.more_topics_url
          @set('loading', false)
          deferred.resolve(items)


  # Put in the appropriate page title based on our view
  updateTitle: (->
    if @get('filterMode') == 'categories'
      Discourse.set('title', Em.String.i18n('categories_list'))
    else
      if @present('category')
        Discourse.set('title', "#{@get('category.name').capitalize()} #{Em.String.i18n('topic.list')}")
      else
        Discourse.set('title', Em.String.i18n('topic.list'))

  ).observes('filterMode', 'category')

  # Create topic button
  createTopic: ->
    topicList = @get('controllers.listTopics.content')
    return unless topicList

    @get('controllers.composer').open
      categoryName: @get('category.name')
      action: Discourse.Composer.CREATE_TOPIC
      draftKey: topicList.get('draft_key')
      draftSequence: topicList.get('draft_sequence')

  createCategory: ->
    @get('controllers.modal')?.show(Discourse.EditCategoryView.create())


Discourse.ListController.reopenClass(filters: ['popular','favorited','read','unread','new','posted'])
