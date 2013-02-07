Discourse.TopicController = Ember.ObjectController.extend Discourse.Presence,

  # A list of usernames we want to filter by
  userFilters: new Em.Set()
  multiSelect: false
  bestOf: false
  showExtraHeaderInfo: false

  needs: ['header', 'modal', 'composer', 'quoteButton']

  filter: (->
    return 'best_of' if @get('bestOf') == true
    return 'user' if @get('userFilters').length > 0
    return null
  ).property('userFilters.[]', 'bestOf')

  filterDesc: (->
    return null unless filter = @get('filter')
    Em.String.i18n("topic.filters.#{filter}")
  ).property('filter')

  selectedPosts: (->
    return null unless posts = @get('content.posts')
    posts.filterProperty('selected')
  ).property('content.posts.@each.selected')

  selectedCount: (->
    return 0 unless @get('selectedPosts')
    @get('selectedPosts').length
  ).property('selectedPosts')

  canMoveSelected: (->
    return false unless @get('content.can_move_posts')

    # For now, we can move it if we can delete it since the posts
    # need to be deleted.
    @get('canDeleteSelected')
  ).property('canDeleteSelected')

  showExtraHeaderInfoChanged: (->
    @set('controllers.header.showExtraInfo', @get('showExtraHeaderInfo'))
  ).observes('showExtraHeaderInfo')

  canDeleteSelected: (->
    selectedPosts = @get('selectedPosts')
    return false unless selectedPosts and selectedPosts.length > 0
    canDelete = true
    selectedPosts.each (p) ->
      unless p.get('can_delete')
        canDelete = false
        return false
    
    canDelete
  ).property('selectedPosts')

  multiSelectChanged: (->
    # Deselect all posts when multi select is turned off
    unless @get('multiSelect')
      if posts = @get('content.posts')
        posts.forEach (p) -> p.set('selected', false)
        
  ).observes('multiSelect')

  hideProgress: (->
    return true unless @get('content.loaded')
    return true unless @get('currentPost')
    return true unless @get('content.highest_post_number') > 1
    @present('filter')
  ).property('filter', 'content.loaded', 'currentPost')

  selectPost: (post) ->
    post.toggleProperty('selected')

  toggleMultiSelect: ->
    @toggleProperty('multiSelect')

  moveSelected: ->
    @get('controllers.modal')?.show(Discourse.MoveSelectedView.create(topic: @get('content'), selectedPosts: @get('selectedPosts')))

  deleteSelected: ->
    bootbox.confirm Em.String.i18n("post.delete.confirm", count: @get('selectedCount')), (result) =>
      if (result)
        Discourse.Post.deleteMany(@get('selectedPosts'))
        @get('content.posts').removeObjects(@get('selectedPosts'))

  jumpTop: ->
    Discourse.routeTo(@get('content.url'))

  jumpBottom: ->
    Discourse.routeTo(@get('content.lastPostUrl'))

  cancelFilter: ->
    @set('bestOf', false)
    @get('userFilters').clear()

  replyAsNewTopic: (post) ->
    composerController = @get('controllers.composer')
    #TODO shut down topic draft cleanly if it exists ... 
    promise = composerController.open
      action: Discourse.Composer.CREATE_TOPIC
      draftKey: Discourse.Composer.REPLY_AS_NEW_TOPIC_KEY

    postUrl = "#{location.protocol}//#{location.host}#{post.get('url')}"
    postLink = "[#{@get('title')}](#{postUrl})"
    promise.then ->
      Discourse.Post.loadQuote(post.get('id')).then (q) ->   
        composerController.appendText("#{Em.String.i18n("post.continue_discussion", postLink: postLink)}\n\n#{q}")

  # Topic related
  reply: ->
    composerController = @get('controllers.composer')
    composerController.open
      topic: @get('content')
      action: Discourse.Composer.REPLY
      draftKey: @get('content.draft_key')
      draftSequence: @get('content.draft_sequence')

  toggleParticipant: (user) ->
    @set('bestOf', false)
    username = Em.get(user, 'username')
    userFilters = @get('userFilters')
    if userFilters.contains(username)
      userFilters.remove(username)
    else
      userFilters.add(username)
    false

  enableBestOf: (e) ->
    @set('bestOf', true)
    @get('userFilters').clear()
    false

  showBestOf: (->
    return false if @get('bestOf') == true
    @get('content.has_best_of') == true
  ).property('bestOf', 'content.has_best_of')

  postFilters: (->
    return {bestOf: true} if @get('bestOf') == true
    return {userFilters: @get('userFilters')}
  ).property('userFilters.[]', 'bestOf')

  reloadTopics: (->
    topic = @get('content')
    return unless topic
    posts = topic.get('posts')
    return unless posts
    posts.clear()  
      
    @set('content.loaded', false)
    Discourse.Topic.find(@get('content.id'), @get('postFilters')).then (result) =>
      first = result.posts.first()
      @set('currentPost', first.post_number) if first
      $('#topic-progress .solid').data('progress', false)
      result.posts.each (p) => 
        posts.pushObject(Discourse.Post.create(p, topic))
      @set('content.loaded', true)

  ).observes('postFilters')

  deleteTopic: (e) ->
    @unsubscribe()

    @get('content').delete =>
      @set('message', "The topic has been deleted")
      @set('loaded', false) 

  toggleVisibility: ->
    @get('content').toggleStatus('visible')

  toggleClosed: ->
    @get('content').toggleStatus('closed')

  togglePinned: ->
    @get('content').toggleStatus('pinned')

  toggleArchived: ->
    @get('content').toggleStatus('archived')

  convertToRegular: ->
    @get('content').convertArchetype('regular')

  startTracking: ->
    screenTrack = Discourse.ScreenTrack.create(topic_id: @get('content.id'))
    screenTrack.start()
    @set('content.screenTrack', screenTrack)

  stopTracking: ->
    @get('content.screenTrack')?.stop()
    @set('content.screenTrack', null)

  # Toggle the star on the topic
  toggleStar: (e) ->
    @get('content').toggleStar()

  # Receive notifications for this topic
  subscribe: ->

    bus = Discourse.MessageBus
    # there is a condition where the view never calls unsubscribe, navigate to a topic from a topic
    bus.unsubscribe('/topic/*')
    bus.subscribe "/topic/#{@get('content.id')}", (data) =>
      topic = @get('content')
      if data.notification_level_change
        topic.set('notification_level', data.notification_level_change)
        topic.set('notifications_reason_id', data.notifications_reason_id)
        return

      posts = topic.get('posts')
      return if posts.some (p) -> p.get('post_number') == data.post_number
      topic.set 'posts_count', topic.get('posts_count') + 1
      topic.set 'highest_post_number', data.post_number
      topic.set 'last_poster', data.user
      topic.set 'last_posted_at', data.created_at
      Discourse.notifyTitle()

  unsubscribe: ->
    topicId = @get('content.id')
    return unless topicId
    bus = Discourse.MessageBus
    bus.unsubscribe("/topic/#{topicId}")

  # Post related methods
  replyToPost: (post) ->
    composerController = @get('controllers.composer')
    quoteController = @get('controllers.quoteButton')
    quotedText = Discourse.BBCode.buildQuoteBBCode(quoteController.get('post'), quoteController.get('buffer'))
    quoteController.set('buffer', '')
   
    if (composerController.get('content.topic.id') == post.get('topic.id') and composerController.get('content.action') == Discourse.Composer.REPLY)
      composerController.set('content.post', post)
      composerController.set('content.composeState', Discourse.Composer.OPEN)
      composerController.appendText(quotedText)
    else
      promise = composerController.open
        post: post
        action: Discourse.Composer.REPLY
        draftKey: post.get('topic.draft_key')
        draftSequence: post.get('topic.draft_sequence')

      promise.then =>
        composerController.appendText(quotedText)

    false

  # Edits a post
  editPost: (post) ->
    @get('controllers.composer').open
      post: post
      action: Discourse.Composer.EDIT
      draftKey: post.get('topic.draft_key')
      draftSequence: post.get('topic.draft_sequence')

  toggleBookmark: (post) ->
    unless Discourse.get('currentUser')
      alert Em.String.i18n("bookmarks.not_bookmarked")
      return

    post.toggleProperty('bookmarked')
    false

  clearFlags: (actionType) ->
    actionType.clearFlags()

  # Who acted on a particular post / action type
  whoActed: (actionType) ->
    actionType.loadUsers()
    false

  like:(e) ->
    like_action = Discourse.get('site.post_action_types').findProperty('name_key', 'like')
    e.context.act(like_action.get('id'))

  # log a post action towards this post
  act: (action) ->
    action.act()
    false

  undoAction: (action) ->
    action.undo()
    false

  showPrivateInviteModal: ->
    modal = Discourse.InvitePrivateModalView.create(topic: @get('content'))
    @get('controllers.modal')?.show(modal)
    false

  showInviteModal:  ->
    @get('controllers.modal')?.show(Discourse.InviteModalView.create(topic: @get('content')))
    false

  # Clicked the flag button
  showFlags: (post) ->
    flagView = Discourse.FlagView.create(post: post, controller: @)
    @get('controllers.modal')?.show(flagView)

  showHistory: (post) ->
    view = Discourse.HistoryView.create(originalPost: post)
    @get('controllers.modal')?.show(view)
    false

  deletePost: (post) ->

    deleted = !!post.get('deleted_at')

    if deleted
      post.set('deleted_at', null)
    else
      post.set('deleted_at', new Date())

    post.delete =>
      # nada
