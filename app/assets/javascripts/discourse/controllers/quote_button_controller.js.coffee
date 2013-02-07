Discourse.QuoteButtonController = Discourse.Controller.extend

  needs: ['topic', 'composer']

  started: null

  # If the buffer is cleared, clear out other state (post)
  bufferChanged: (->
    @set('post', null) if @blank('buffer')
  ).observes('buffer')


  mouseDown: (e) ->
    @started = [e.pageX, e.pageY]

  mouseUp: (e) ->
    if @started[1] > e.pageY
      @started = [e.pageX, e.pageY]

  selectText: (e) ->
    return unless Discourse.get('currentUser')
    return unless @get('controllers.topic.content.can_create_post')

    selectedText = Discourse.Utilities.selectedText()
    return if @get('buffer') == selectedText
    return if @get('lastSelected') == selectedText

    @set('post', e.context)
    @set('buffer', selectedText)

    top = e.pageY + 5
    left = e.pageX + 5
    $quoteButton = $('.quote-button')
    if @started
      top = @started[1] - 50
      left = ((left - @started[0]) / 2) + @started[0] - ($quoteButton.width() / 2)

    $quoteButton.css(top: top, left: left)
    @started = null

    false

  quoteText: (e) ->

    e.stopPropagation()
    post = @get('post')

    composerController = @get('controllers.composer')

    composerOpts =
      post: post
      action: Discourse.Composer.REPLY
      draftKey: @get('post.topic.draft_key')

    # If the composer is associated with a different post, we don't change it.
    if composerPost = composerController.get('content.post')
      composerOpts.post = composerPost if (composerPost.get('id') != @get('post.id'))

    buffer = @get('buffer')
    quotedText = Discourse.BBCode.buildQuoteBBCode(post, buffer)

    if composerController.wouldLoseChanges()
      composerController.appendText(quotedText)
    else
      composerController.open(composerOpts).then =>
        composerController.appendText(quotedText)

    @set('buffer', '')

    false
