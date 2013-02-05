window.Discourse.CategoryList = Discourse.Model.extend({})


window.Discourse.CategoryList.reopenClass

  categoriesFrom: (result) ->
    categories = Em.A()

    users = @extractByKey(result.featured_users, Discourse.User)

    result.category_list.categories.each (c) ->
      if c.featured_user_ids
        c.featured_users = c.featured_user_ids.map (u) -> users[u]
      if c.topics
        c.topics = c.topics.map (t) -> Discourse.Topic.create(t)

      categories.pushObject(Discourse.Category.create(c))

    categories

  list: (filter) ->
    promise = new RSVP.Promise()
    jQuery.getJSON("/#{filter}.json").then (result) =>
      categoryList = Discourse.TopicList.create()
      categoryList.set('can_create_category', result.category_list.can_create_category)
      categoryList.set('categories', @categoriesFrom(result))
      categoryList.set('loaded', true)
      promise.resolve(categoryList)
    promise
