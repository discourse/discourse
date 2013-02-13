window.Discourse.ListCategoryRoute = Discourse.FilteredListRoute.extend
  setupController: (controller, model) ->

    slug = Em.get(model, 'slug')
    category = Discourse.get('site.categories').findProperty('slug', slug)
    category ||= Discourse.Category.create(name: slug, slug: slug)

    listController = @controllerFor('list')
    listController.set('filterMode', "category/#{category.get('slug')}")
    listController.load("category/#{category.get('slug')}").then (topicList) =>
      listController.set('canCreateTopic', topicList.get('can_create_topic'))
      listController.set('category',category)
      @controllerFor('listTopics').set('content', topicList)
