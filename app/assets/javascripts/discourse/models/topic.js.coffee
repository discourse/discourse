Discourse.Topic = Discourse.Model.extend Discourse.Presence,
  categoriesBinding: 'Discourse.site.categories'

  fewParticipants: (->
    return null unless @present('participants')
    return @get('participants').slice(0, 3)
  ).property('participants')

  canConvertToRegular: (->
    a = @get('archetype')
    a != 'regular' && a != 'private_message'
  ).property('archetype')

  convertArchetype: (archetype) ->
    a = @get('archetype')
    if a != 'regular' && a != 'private_message'
      @set('archetype','regular')
      jQuery.post @get('url'),
        _method: 'put'
        archetype: 'regular'

  category: (->
    if @get('categories')
      @get('categories').findProperty('name', @get('categoryName'))
  ).property('categoryName', 'categories')

  url: (->
    "/t/#{@get('slug')}/#{@get('id')}"
  ).property('id', 'slug')

  # Helper to build a Url with a post number
  urlForPostNumber: (postNumber) ->
    url = @get('url')
    url += "/#{postNumber}" if postNumber and (postNumber > 1)
    url

  lastReadUrl: (-> @urlForPostNumber(@get('last_read_post_number')) ).property('url', 'last_read_post_number')
  lastPostUrl: (-> @urlForPostNumber(@get('highest_post_number')) ).property('url', 'highest_post_number')

  # The last post in the topic
  lastPost: -> @get('posts').last()

  postsChanged: ( ->
    posts = @get('posts')
    last = posts.last()
    return unless last && last.set && !last.lastPost

    posts.each (p)->
      p.set('lastPost', false) if p.lastPost
    last.set('lastPost',true)
    return true
  ).observes('posts.@each','posts')

  # The amount of new posts to display. It might be different than what the server
  # tells us if we are still asynchronously flushing our "recently read" data.
  # So take what the browser has seen into consideration.
  displayNewPosts: (->

    if highestSeen = Discourse.get('highestSeenByTopic')[@get('id')]
      delta = highestSeen - @get('last_read_post_number')
      if delta > 0
        result = (@get('new_posts') - delta)
        result = 0 if result < 0
        return result

    @get('new_posts')

  ).property('new_posts', 'id')

  displayTitle: (->
    return null unless @get('title')
    return @get('title') unless @get('category')
    matches = @get('title').match(/^([a-zA-Z0-9]+\: )?(.*)/)
    return matches[2]
  ).property('title')

  # The coldmap class for the age of the topic
  ageCold: (->
    return unless lastPost = @get('last_posted_at')
    return unless createdAt = @get('created_at')

    daysSinceEpoch = (dt) ->
      # 1000 * 60 * 60 * 24 = days since epoch
      dt.getTime() / 86400000

    # Show heat on age
    nowDays = daysSinceEpoch(new Date())
    createdAtDays = daysSinceEpoch(new Date(createdAt))
    if daysSinceEpoch(new Date(lastPost)) >  nowDays - 90
      return 'coldmap-high' if createdAtDays < nowDays - 60
      return 'coldmap-med' if createdAtDays < nowDays - 30
      return 'coldmap-low' if createdAtDays < nowDays - 14

    null
  ).property('age', 'created_at')

  archetypeObject: (->
    Discourse.get('site.archetypes').findProperty('id', @get('archetype'))
  ).property('archetype')

  isPrivateMessage: (->
    @get('archetype') == 'private_message'
  ).property('archetype')

  # Does this topic only have a single post?
  singlePost: (->
    @get('posts_count') == 1
  ).property('posts_count')

  toggleStatus: (property) ->
    @toggleProperty(property)
    jQuery.post "#{@get('url')}/status", _method: 'put', status: property, enabled: if @get(property) then 'true' else 'false'

  toggleStar: ->
    @toggleProperty('starred')
    jQuery.ajax
      url: "#{@get('url')}/star"
      type: 'PUT'
      data:
        starred: if @get('starred') then true else false
      error: (error) =>
        @toggleProperty('starred')
        errors = jQuery.parseJSON(error.responseText).errors
        bootbox.alert(errors[0])

  # Save any changes we've made to the model
  save: ->
    # Don't save unless we can
    return unless @get('can_edit')

    jQuery.post @get('url'),
      _method: 'put'
      title: @get('title')
      category: @get('category.name')

  # Reset our read data for this topic
  resetRead: (callback) ->
    $.ajax "/t/#{@get('id')}/timings",
      type: 'DELETE'
      success: -> callback?()

  # Invite a user to this topic
  inviteUser: (user) ->
    $.ajax
      type: 'POST'
      url: "/t/#{@get('id')}/invite",
      data: {user: user}

  # Delete this topic
  delete: (callback) ->
    $.ajax "/t/#{@get('id')}",
      type: 'DELETE'
      success: -> callback?()

  # Load the posts for this topic
  loadPosts: (opts) ->

    opts = {} unless opts

    # Load the first post by default
    opts.nearPost ||= 1 unless opts.bestOf


    # If we already have that post in the DOM, jump to it
    return if Discourse.TopicView.scrollTo @get('id'), opts.nearPost

    Discourse.Topic.find @get('id'),
      nearPost: opts.nearPost
      bestOf: opts.bestOf
      trackVisit: opts.trackVisit
    .then (result) =>

      # If loading the topic succeeded...
      # Update the slug if different
      @set('slug', result.slug) if result.slug

      # If we want to scroll to a post that doesn't exist, just pop them to the closest
      # one instead. This is likely happening due to a deleted post.
      opts.nearPost = parseInt(opts.nearPost)
      closestPostNumber = 0
      postDiff = Number.MAX_VALUE
      result.posts.each (p) ->
        diff = Math.abs(p.post_number - opts.nearPost)
        if diff < postDiff
          postDiff = diff
          closestPostNumber = p.post_number
          return false if diff == 0
      opts.nearPost = closestPostNumber


      @get('participants').clear() if @get('participants')

      @set('suggested_topics', Em.A()) if result.suggested_topics
      @mergeAttributes result, suggested_topics: Discourse.Topic
      @set('posts', Em.A())

      if opts.trackVisit and result.draft and result.draft.length > 0
        Discourse.openComposer
          draft: Discourse.Draft.getLocal(result.draft_key, result.draft)
          draftKey: result.draft_key
          draftSequence: result.draft_sequence
          topic: @
          ignoreIfChanged: true

      # Okay this is weird, but let's store the length of the next post
      # when there
      lastPost = null
      result.posts.each (p) =>
        p.scrollToAfterInsert = opts.nearPost
        post = Discourse.Post.create(p)
        post.set('topic', @)
        @get('posts').pushObject(post)

        lastPost = post

      @set('loaded', true)
    , (result) =>
      @set('missing', true)
      @set('message', Em.String.i18n('topic.not_found.description'))

  notificationReasonText: (->
    locale_string = "topic.notifications.reasons.#{@notification_level}"
    if typeof @notifications_reason_id == 'number'
      locale_string += "_#{@notifications_reason_id}"
    Em.String.i18n(locale_string, username: Discourse.currentUser.username.toLowerCase())
  ).property('notifications_reason_id')

  updateNotifications: (v)->
    @set('notification_level', v)
    @set('notifications_reason_id', null)
    $.ajax
      url: "/t/#{@get('id')}/notifications"
      type: 'POST'
      data: {notification_level: v}

  # use to add post to topics protecting from dupes
  pushPosts: (newPosts)->
    map = {}
    posts = @get('posts')
    posts.each (p)->
      map["#{p.post_number}"] = true

    newPosts.each (p)->
      posts.pushObject(p) unless map[p.get('post_number')]

window.Discourse.Topic.reopenClass

  NotificationLevel:
    WATCHING: 3
    TRACKING: 2
    REGULAR: 1
    MUTE: 0

  # Load a topic, but accepts a set of filters
  #
  #  options:
  #    onLoad - the callback after the topic is loaded
  find: (topicId, opts) ->
    url = "/t/#{topicId}"
    url += "/#{opts.nearPost}" if opts.nearPost

    data = {}
    data.posts_after = opts.postsAfter if opts.postsAfter
    data.posts_before = opts.postsBefore if opts.postsBefore
    data.track_visit = true if opts.trackVisit

    # Add username filters if we have them
    if opts.userFilters and opts.userFilters.length > 0
      data.username_filters = []
      opts.userFilters.forEach (username) => data.username_filters.push(username)

    # Add the best of filter if we have it
    data.best_of = true if opts.bestOf == true

    # Check the preload store. If not, load it via JSON
    promise = new RSVP.Promise()
    PreloadStore.get("topic_#{topicId}", -> jQuery.getJSON url + ".json", data).then (result) ->
      first = result.posts.first()
      first.bestOfFirst = true if first and opts and opts.bestOf
      promise.resolve(result)
    , (result) -> promise.reject(result)

    promise

  # Create a topic from posts
  movePosts: (topicId, title, postIds) ->
    $.ajax "/t/#{topicId}/move-posts",
      type: 'POST'
      data:
        title: title
        post_ids: postIds

  create: (obj, topicView) ->
    Object.tap @_super(obj), (result) =>
      if result.participants
        result.participants = result.participants.map (u) => Discourse.User.create(u)

        result.fewParticipants = Em.A()
        result.participants.each (p) =>
          return false if result.fewParticipants.length >= 8
          result.fewParticipants.pushObject(p)
          true
