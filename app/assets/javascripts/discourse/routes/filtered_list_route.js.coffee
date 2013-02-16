# Create the topic list filtered routes
window.Discourse.FilteredListRoute = Discourse.Route.extend
  exit: ->
    @_super()
    listController = @controllerFor('list')
    listController.set('canCreateTopic', false)
    listController.set('filterMode', '')
    listController.set('allLoaded', false)


  renderTemplate: ->
    @render 'listTopics', into: 'list', outlet: 'listView', controller: 'listTopics'
  setupController: ->
    listController = @controllerFor('list')
    listTopicsController = @controllerFor('listTopics')
    listController.set('filterMode', @filter)
    listTopicsController.get('content')?.set('loaded', false)
    listController.load(@filter).then (topicList) =>
      listController.set('category', null)
      listController.set('canCreateTopic', topicList.get('can_create_topic'))
      listTopicsController.set('content', topicList)

Discourse.ListController.filters.each (filter) ->
  window.Discourse["List#{filter.capitalize()}Route"] = Discourse.FilteredListRoute.extend(filter: filter)


