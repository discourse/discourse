window.Discourse.TopicRoute = Discourse.Route.extend
  model: (params) ->
    if currentModel = @controllerFor('topic')?.get('content')
      return currentModel if currentModel.get('id') is parseInt(params.id)
    Discourse.Topic.create(params)

  enter: ->
    Discourse.set('transient.lastTopicIdViewed', parseInt(@modelFor('topic').get('id')))
  exit: ->
    topicController = @controllerFor('topic')
    topicController.cancelFilter()
    topicController.set('multiSelect', false)

    if headerController = @controllerFor('header')
      headerController.set('topic', null)
      headerController.set('showExtraInfo', false)

  setupController: (controller, model) ->
    controller.set('showExtraHeaderInfo', false)
    headerController = @controllerFor('header')
    headerController?.set('topic', model)
