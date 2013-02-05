window.Discourse.TopicList = Discourse.Model.extend

  emptyListTip: (->
    return null unless @get('loaded')
    
    t = @get('topics')
    return null if t && t.length > 0

    Em.String.i18n('topics.no_' + @get('filter'))
  ).property('topics', 'topics@each', 'filter', 'loaded')

  loadMoreTopics: ->
    promise = new RSVP.Promise()
    if moreUrl = @get('more_topics_url')
      Discourse.replaceState("/#{@get('filter')}/more")
      $.ajax moreUrl,
        success: (result) =>
          if result
            newTopics = Discourse.TopicList.topicsFrom(result)
            topics = @get('topics')
            topicIds = []
            topics.each (t) -> topicIds[t.get('id')] = true
            newTopics.each (t) -> topics.pushObject(t) unless topicIds[t.get('id')]
            @set('more_topics_url', result.topic_list.more_topics_url)
            Discourse.set('transient.topicsList', this)

          promise.resolve(if result.topic_list.more_topics_url then true else false)
    else
      promise.resolve(false)

    promise

  insert: (json) ->
    newTopic = Discourse.TopicList.decodeTopic(json)
    
    # New Topics are always unseen
    newTopic.set('unseen', true)

    newTopic.set('highlightAfterInsert', true)
    @get('inserted').unshiftObject(newTopic)


window.Discourse.TopicList.reopenClass

  decodeTopic: (result) ->
    categories = @extractByKey(result.categories, Discourse.Category)
    users = @extractByKey(result.users, Discourse.User)

    topic = result.topic_list_item
    topic.category = categories[topic.category]
    topic.posters.each (p) ->
      p.user = users[p.user_id] || users[p.user]

    Discourse.Topic.create(topic)

  topicsFrom: (result) ->
    # Stitch together our side loaded data
    categories = @extractByKey(result.categories, Discourse.Category)
    users = @extractByKey(result.users, Discourse.User)

    topics = Em.A()
    result.topic_list.topics.each (ft) ->
      ft.category = categories[ft.category_id]
      ft.posters.each (p) -> p.user = users[p.user_id]
      topics.pushObject(Discourse.Topic.create(ft))
    topics

  list: (menuItem) ->

    filter = menuItem.name
    topic_list = Discourse.TopicList.create()
    topic_list.set('inserted', Em.A())
    topic_list.set('filter', filter)

    url = "/#{filter}.json"
    if menuItem.filters && menuItem.filters.length > 0
      url += "?exclude_category=" + menuItem.filters[0].substring(1)
    
    if list = Discourse.get('transient.topicsList')
      if (list.get('filter') is filter) and window.location.pathname.indexOf('more') > 0
        promise = new RSVP.Promise()
        list.set('loaded', true)
        promise.resolve(list)
        return promise

    ## Clear the cache if exists
    Discourse.set('transient.topicsList', null)
    Discourse.set('transient.topicListScrollPos', null)

    promise = new RSVP.Promise()
    found = PreloadStore.contains('topic_list')
    PreloadStore.get("topic_list", -> jQuery.getJSON(url)).then (result) ->
      topic_list.set('topics', Discourse.TopicList.topicsFrom(result))
      topic_list.set('can_create_topic', result.topic_list.can_create_topic)
      topic_list.set('more_topics_url', result.topic_list.more_topics_url)
      topic_list.set('filter_summary', result.topic_list.filter_summary)
      topic_list.set('draft_key', result.topic_list.draft_key)
      topic_list.set('draft_sequence', result.topic_list.draft_sequence)
      topic_list.set('draft', result.topic_list.draft)
      if result.topic_list.filtered_category
        topic_list.set('category', Discourse.Category.create(result.topic_list.filtered_category))
      topic_list.set('loaded', true)
      promise.resolve(topic_list)

    promise
