window.Discourse.TopicView = Ember.View.extend Discourse.Scrolling,
  templateName: 'topic'
  topicBinding: 'controller.content'
  userFiltersBinding: 'controller.userFilters'
  classNameBindings: ['controller.multiSelect:multi-select', 'topic.archetype']
  siteBinding: 'Discourse.site'
  categoriesBinding: 'site.categories'
  progressPosition: 1

  menuVisible: true
  

  SHORT_POST: 1200

  # Update the progress bar using sweet animations
  updateBar: (->
    return unless @get('topic.loaded')
    $topicProgress = $('#topic-progress')
    return unless $topicProgress.length
    
    # Don't show progress when there is only one post
    if @get('topic.highest_post_number') is 1
      $topicProgress.hide()
    else
      $topicProgress.show()

    ratio = @get('progressPosition') / @get('topic.highest_post_number')

    totalWidth = $topicProgress.width()
    progressWidth = ratio * totalWidth
    bg = $topicProgress.find('.bg')

    bg.stop(true,true)
    currentWidth = bg.width()

    if currentWidth == totalWidth
      bg.width(currentWidth - 1)

    if progressWidth == totalWidth
      bg.css("border-right-width", "0px")
    else
      bg.css("border-right-width", "1px")
      
    if currentWidth == 0
      bg.width(progressWidth)
    else
      bg.animate(width: progressWidth, 400)

  ).observes('progressPosition', 'topic.highest_post_number', 'topic.loaded')

  updateTitle: (->
    title = @get('topic.title')
    Discourse.set('title', title) if title
  ).observes('topic.loaded', 'topic.title')

  newPostsPresent: (->
    if @get('topic.highest_post_number')
      @updateBar()
      @examineRead()
  ).observes('topic.highest_post_number')

  currentPostChanged: (->

    current = @get('controller.currentPost')
    topic = @get('topic')
    return unless current and topic

    @set('maxPost', current) if current > (@get('maxPost') || 0)

    postUrl = topic.get('url')
    if current > 1
      postUrl += "/#{current}"
    else
      postUrl += "/best_of" if @get('controller.bestOf')

    Discourse.replaceState(postUrl)
      
    # Show appropriate jump tools
    if current is 1 then $('#jump-top').attr('disabled', true) else $('#jump-top').attr('disabled', false)
    if current is @get('topic.highest_post_number') then $('#jump-bottom').attr('disabled', true) else $('#jump-bottom').attr('disabled', false)

  ).observes('controller.currentPost', 'controller.bestOf', 'topic.highest_post_number')

  composeChanged: (->
    composerController = Discourse.get('router.composerController')
    composerController.clearState()
    composerController.set('topic', @get('topic'))
  ).observes('composer')

  # This view is being removed. Shut down operations
  willDestroyElement: ->
    @unbindScrolling()
    @get('controller').unsubscribe()
    @get('screenTrack')?.stop()
    @set('screenTrack', null)
    $(window).unbind 'scroll.discourse-on-scroll'
    $(document).unbind 'touchmove.discourse-on-scroll'
    $(window).unbind 'resize.discourse-on-scroll'
    @resetExamineDockCache()

  didInsertElement: (e) ->
    onScroll = Discourse.debounce((=> @onScroll()), 10)
    $(window).bind 'scroll.discourse-on-scroll', onScroll
    $(document).bind 'touchmove.discourse-on-scroll', onScroll
    $(window).bind 'resize.discourse-on-scroll', onScroll

    @bindScrolling()
    @get('controller').subscribe()

    # Insert our screen tracker
    screenTrack = Discourse.ScreenTrack.create(topic_id: @get('topic.id'))
    screenTrack.start()
    @set('screenTrack', screenTrack)

    # Track the user's eyeline
    eyeline = new Discourse.Eyeline('.topic-post')
    eyeline.on 'saw', (e) => @postSeen(e.detail)
    eyeline.on 'sawBottom', (e) => @nextPage(e.detail)
    eyeline.on 'sawTop', (e) => @prevPage(e.detail)
    @set('eyeline', eyeline)

    @.$().on 'mouseup.discourse-redirect', '.cooked a, a.track-link', (e) ->
      Discourse.ClickTrack.trackClick(e)

    @onScroll()

  # Triggered from the post view all posts are rendered
  postsRendered: (postDiv, post)->
    $window = $(window)
    $lastPost = $('.row:last')
    # we consider stuff at the end of the list as read, right away (if it is visible)
    if $window.height() + $window.scrollTop() >= $lastPost.offset().top + $lastPost.height()
      @examineRead()
    else
      # last is not in view, so only examine in 2 seconds
      Em.run.later =>
        @examineRead()
      , 2000

  resetRead: (e) ->
    @get('screenTrack').cancel()
    @set('screenTrack', null)
    @get('controller').unsubscribe()

    @get('topic').resetRead =>
      @set('controller.message', "Your read position has been reset.")
      @set('controller.loaded', false)

  # Called for every post seen
  postSeen: ($post) ->
    @set('postNumberSeen', null)
    postView = Ember.View.views[$post.prop('id')]
    if postView
      post = postView.get('post')
      @set('postNumberSeen', post.get('post_number'))
      if post.get('post_number') > (@get('topic.last_read_post_number') || 0)
        @set('topic.last_read_post_number', post.get('post_number'))
      unless post.get('read')
        post.set('read', true)
        @get('screenTrack')?.guessedSeen(post.get('post_number'))
      
  observeFirstPostLoaded: (->
    posts = @get('topic.posts')

    # TODO topic.posts stores non ember objects in it for a period of time, this is bad
    loaded = posts && posts[0] && posts[0].post_number == 1

    # I avoided a computed property cause I did not want to set it, over and over again
    old = @get('firstPostLoaded')
    if loaded
      @set('firstPostLoaded', true) unless old == true
    else
      @set('firstPostLoaded', false) unless old == false

  ).observes('topic.posts.@each')

  # Load previous posts if there are some
  prevPage: ($post) ->
    postView = Ember.View.views[$post.prop('id')]
    return unless postView
    post = postView.get('post')
    return unless post

    # We don't load upwards from the first page
    return if post.post_number == 1

    # double check
    if @topic && @topic.posts && @topic.posts.length > 0 && @topic.posts.first().post_number != post.post_number
      return
  
    # half mutex
    return if @loading

    @set('loading', true)
    @set('loadingAbove', true)

    opts = $.extend {postsBefore: post.get('post_number')}, @get('controller.postFilters')
    Discourse.Topic.find(@get('topic.id'), opts).then (result) =>
      posts = @get('topic.posts')

      # Add a scrollTo record to the last post inserted to the DOM
      lastPostNum = result.posts.first().post_number
      result.posts.each (p) =>
        newPost = Discourse.Post.create(p, @get('topic'))
        if p.post_number == lastPostNum
          newPost.set 'scrollTo', top: $(window).scrollTop(), height: $(document).height()
        posts.unshiftObject(newPost)

      @set('loading', false)
      @set('loadingAbove', false)


  fullyLoaded: (->
    @seenBottom || @topic.at_bottom
  ).property('topic.at_bottom', 'seenBottom')

  # Load new posts if there are some
  nextPage: ($post) ->
    
    return if @loading || @seenBottom
    postView = Ember.View.views[$post.prop('id')]
    return unless postView
    post = postView.get('post')
    @loadMore(post)

  postCountChanged:(->
    @set('seenBottom',false)
    @get('eyeline')?.update()
  ).observes('topic.highest_post_number')

  loadMore: (post)->
    return if @loading || @seenBottom

    # Don't load if we know we're at the bottom
    if @get('topic.highest_post_number') is post.get('post_number')
      @get('eyeline')?.flushRest()

      # Update our current post to the last number we saw
      @set('controller.currentPost', postNumberSeen) if postNumberSeen = @get('postNumberSeen')
      return

    # Don't double load ever
    if @topic.posts.last().post_number != post.post_number
      return

    @set('loadingBelow', true)
    @set('loading', true)
    opts = $.extend {postsAfter: post.get('post_number')}, @get('controller.postFilters')
    Discourse.Topic.find(@get('topic.id'), opts).then (result) =>
      if result.at_bottom || result.posts.length == 0
        @set('seenBottom', 'true')
     
      @get('topic').pushPosts result.posts.map (p) =>
        Discourse.Post.create(p, @get('topic'))
      
      if result.suggested_topics
        suggested = Em.A()
        result.suggested_topics.each (st) ->
          suggested.pushObject(Discourse.Topic.create(st))
        @set('topic.suggested_topics', suggested)

      @set('loadingBelow', false)
      @set('loading', false)

  # Examine which posts are on the screen and mark them as read. Also figure out if we
  # need to load more posts.  
  examineRead: ->
    # Track posts time on screen
    @get('screenTrack')?.scrolled()

    # Update what we can see
    @get('eyeline')?.update()

    # Update our current post to the last number we saw
    @set('controller.currentPost', postNumberSeen) if postNumberSeen = @get('postNumberSeen')

  cancelEdit: ->
    @set('editingTopic', false)

  finishedEdit: ->
    if @get('editingTopic')
      topic = @get('topic')
      topic.set('title', $('#edit-title').val())
      topic.save()
      @set('editingTopic', false)

  editTopic: ->
    return false unless @get('topic.can_edit')
    @set('editingTopic', true)
    false

  showFavoriteButton: (->
    Discourse.currentUser && !@get('topic.isPrivateMessage')
  ).property('topic.isPrivateMessage')

  resetExamineDockCache: ->
    @docAt = null
    @dockedTitle = false
    @dockedCounter = false

  detectDockPosition: ->
    rows = $(".topic-post")
    return unless rows.length > 0

    i = parseInt(rows.length / 2, 10)
    increment = parseInt(rows.length / 4, 10)
    goingUp = `undefined`

    winOffset = window.pageYOffset || $('html').scrollTop()
    winHeight = window.innerHeight || $(window).height()

    loop
      break if i is 0 or (i >= rows.length - 1)

      current = $(rows[i])
      offset = current.offset()

      if offset.top - winHeight < winOffset
        if offset.top + current.outerHeight() - window.innerHeight > winOffset
          break
        else
          i = i + increment
          break  if goingUp isnt `undefined` and increment is 1 and not goingUp
          goingUp = true
      else
        i = i - increment
        break  if goingUp isnt `undefined` and increment is 1 and goingUp
        goingUp = false

      if increment > 1
        increment = parseInt(increment / 2, 10)
        goingUp = `undefined`
      if increment == 0
        increment = 1
        goingUp = `undefined`

    postView = Ember.View.views[rows[i].id]
    return unless postView
    post = postView.get('post')
    return unless post
    @set('progressPosition', post.get('post_number'))
  
    return
  
  ensureDockIsTestedOnChange: (->
    # this is subtle, firstPostLoaded will trigger ember to render the view containing #topic-title
    #  onScroll needs do know about it to be able to make a decision about the dock
    #

    Em.run.next @, @onScroll
  ).observes('firstPostLoaded')

  onScroll: ->
    @detectDockPosition()
    offset = window.pageYOffset || $('html').scrollTop()
    firstLoaded = @get('firstPostLoaded')

    unless @docAt
      title = $('#topic-title')
      if title && title.length == 1
        @docAt = title.offset().top

    if @docAt
      @set('controller.showExtraHeaderInfo', offset >= @docAt || !firstLoaded)
    else
      @set('controller.showExtraHeaderInfo', !firstLoaded)


    # there is a whole bunch of caching we could add here
    $lastPost = $('.last-post')
    lastPostOffset = $lastPost.offset()

    return unless lastPostOffset # there is an edge case while stuff is loading

    if offset >= (lastPostOffset.top + $lastPost.height()) - $(window).height()
      unless @dockedCounter
        $('#topic-progress-wrapper').addClass('docked')
        @dockedCounter = true
    else
      if @dockedCounter
        $('#topic-progress-wrapper').removeClass('docked')
        @dockedCounter = false

  browseMoreMessage: (->
    opts = {popularLink: "<a href=\"/\">#{Em.String.i18n("topic.view_popular_topics")}</a>"}

    if category = @get('controller.content.category')
      opts.catLink = Discourse.Utilities.categoryLink(category)
      Ember.String.i18n("topic.read_more_in_category", opts)
    else
      opts.catLink = "<a href=\"/categories\">#{Em.String.i18n("topic.browse_all_categories")}</a>"
      Ember.String.i18n("topic.read_more", opts)
  ).property()


  # The window has been scrolled
  scrolled: (e) -> @examineRead()
    
window.Discourse.TopicView.reopenClass

  # Scroll to a given post, if in the DOM. Returns whether it was in the DOM or not.
  scrollTo: (topicId, postNumber, callback) ->


    # Make sure we're looking at the topic we want to scroll to
    return false unless parseInt(topicId) == parseInt($('#topic').data('topic-id'))

    existing = $("#post_#{postNumber}")
    if existing.length
      if postNumber == 1
        $('html, body').scrollTop(0)
      else
        $('html, body').scrollTop(existing.offset().top - 55)
      return true

    false

