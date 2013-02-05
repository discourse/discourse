window.Discourse.TopicBestOfRoute = Discourse.Route.extend
  setupController: (controller, params) ->
    params = params || {}
    params.trackVisit = true
    params.bestOf = true
    topicController = @controllerFor('topic')
    topicController.cancelFilter()
    topicController.set('bestOf', true)
    @modelFor('topic').loadPosts(params)
