window.Discourse.TopicFromParamsRoute = Discourse.Route.extend
  setupController: (controller, params) ->
    params = params || {}
    params.trackVisit = true
    topicController = @controllerFor('topic')
    topicController.cancelFilter()
    @modelFor('topic').loadPosts(params)