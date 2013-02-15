window.Discourse.ListCategoryRoute = Discourse.FilteredListRoute.extend
  setupController: (controller, model) ->

    slug = Em.get(model, 'slug')
    category = Discourse.get('site.categories').findProperty('slug', slug)
    category ||= Discourse.get('site.categories').findProperty('id', parseInt(slug))
    category ||= Discourse.Category.create(name: slug, slug: slug)

    listController = @controllerFor('list')

    urlId = Discourse.Utilities.categoryUrlId(category)
    listController.set('filterMode', "category/#{urlId}")
    listController.load("category/#{urlId}").then (topicList) =>
      listController.set('canCreateTopic', topicList.get('can_create_topic'))
      listController.set('category',category)
      @controllerFor('listTopics').set('content', topicList)
