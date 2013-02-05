window.Discourse.ListCategoryRoute = Discourse.FilteredListRoute.extend
  serialize: (params) -> slug: params.get('slug')

  setupController: (controller, model) ->
    listController = @controllerFor('list')
    listController.set('filterMode', "category/#{model.slug}")
    listController.load("category/#{model.slug}").then (topicList) =>
      listController.set('canCreateTopic', topicList.get('can_create_topic'))
      listController.set('category', Discourse.Category.create(name: model.slug))
      @controllerFor('listTopics').set('content', topicList)