window.Discourse.PostView = Ember.View.extend
  classNames: ['topic-post', 'clearfix']
  templateName: 'post'
  classNameBindings: ['lastPostClass', 'postTypeClass', 'selectedClass', 'post.hidden:hidden', 'isDeleted:deleted', 'parentPost:replies-above']
  siteBinding: Ember.Binding.oneWay('Discourse.site')
  composeViewBinding: Ember.Binding.oneWay('Discourse.composeView')
  quoteButtonViewBinding: Ember.Binding.oneWay('Discourse.quoteButtonView')
  postBinding: 'content'

  isDeleted: (->
    !!@get('post.deleted_at')
  ).property('post.deleted_at')

  #TODO really we should do something cleaner here... this makes it work in debug but feels really messy
  screenTrack: (->
    parentView = @get('parentView')
    screenTrack = null
    while parentView && !screenTrack
      screenTrack = parentView.get('screenTrack')
      parentView = parentView.get('parentView')
    screenTrack
  ).property('parentView')

  lastPostClass: (->
    return 'last-post' if @get('post.lastPost')
  ).property('post.lastPost')

  postTypeClass: (->
    return 'moderator' if @get('post.post_type') == Discourse.Post.MODERATOR_ACTION_TYPE
    'regular'
  ).property('post.post_type')

  selectedClass: (->
    return 'selected' if @get('post.selected')
    null
  ).property('post.selected')

  # If the cooked content changed, add the quote controls
  cookedChanged: (->
    Em.run.next => @insertQuoteControls()
  ).observes('post.cooked')

  init: ->
    @._super()
    @set('context', @get('content'))

  mouseDown: (e) ->
    if qbc = Discourse.get('router.quoteButtonController')
      qbc.mouseDown(e)

  mouseUp: (e) ->
    if qbc = Discourse.get('router.quoteButtonController')
      qbc.mouseUp(e)

    if @get('controller.multiSelect') && (e.metaKey || e.ctrlKey)
      @toggleProperty('post.selected')

    $target = $(e.target)
    return unless $target.closest('.cooked').length > 0
    if qbc = @get('controller.controllers.quoteButton')
      e.context = @get('post')
      qbc.selectText(e)


  selectText: (->
    return Em.String.i18n('topic.multi_select.selected', count: @get('controller.selectedCount')) if @get('post.selected')
    Em.String.i18n('topic.multi_select.select')
  ).property('post.selected', 'controller.selectedCount')

  repliesHidden: (->
    !@get('repliesShown')
  ).property('repliesShown')

  # Click on the replies button
  showReplies: ->
    if @get('repliesShown')
      @set('repliesShown', false)
    else
      @get('post').loadReplies().then => @set('repliesShown', true)

    false

  # Toggle visibility of parent post
  toggleParent: (e) ->

    $parent = @.$('.parent-post')
    if @get('parentPost')
      $('nav', $parent).removeClass('toggled')

      # Don't animate on touch
      if Discourse.get('touch')
        $parent.hide()
        @set('parentPost', null)
      else
        $parent.slideUp => @set('parentPost', null)

    else
      post = @get('post')
      @set('loadingParent', true)
      $('nav', $parent).addClass('toggled')
      Discourse.Post.loadByPostNumber post.get('topic_id'), post.get('reply_to_post_number'), (result) =>
        @set('loadingParent', false)
        @set('parentPost', result)

    false

  updateQuoteElements: ($aside, desc) ->
    navLink = ""

    quoteTitle = Em.String.i18n("post.follow_quote")
    if postNumber = $aside.data('post')

      # If we have a topic reference
      if topicId = $aside.data('topic')
        topic = @get('controller.content')

        # If it's the same topic as ours, build the URL from the topic object
        if topic and topic.get('id') is topicId
          navLink = "<a href='#{topic.urlForPostNumber(postNumber)}' title='#{quoteTitle}' class='back'></a>"
        else
          # Made up slug should be replaced with canonical URL
          navLink = "<a href='/t/via-quote/#{topicId}/#{postNumber}' title='#{quoteTitle}' class='quote-other-topic'></a>"
      else if topic = @get('controller.content')
        # assume the same topic
        navLink = "<a href='#{topic.urlForPostNumber(postNumber)}' title='#{quoteTitle}' class='back'></a>"

    # Only add the expand/contract control if it's not a full post
    expandContract = ""
    unless $aside.data('full')
      expandContract = "<i class='icon-#{desc}' title='expand/collapse'></i>"
      $aside.css('cursor', 'pointer')

    $('.quote-controls', $aside).html("#{expandContract}#{navLink}")

  toggleQuote: ($aside) ->

    @toggleProperty('quoteExpanded')

    if @get('quoteExpanded')
      @updateQuoteElements($aside, 'chevron-up')

      # Show expanded quote
      $blockQuote = $('blockquote', $aside)
      @originalContents = $blockQuote.html()

      originalText = $blockQuote.text().trim()

      $blockQuote.html(Em.String.i18n("loading"))

      post = @get('post')
      topic_id = post.get('topic_id')
      topic_id = $aside.data('topic') if $aside.data('topic')

      jQuery.getJSON "/posts/by_number/#{topic_id}/#{$aside.data('post')}", (result) =>
        parsed = $(result.cooked)
        parsed.replaceText(originalText, "<span class='highlighted'>#{originalText}</span>")

        $blockQuote.showHtml(parsed)
    else
      # Hide expanded quote
      @updateQuoteElements($aside, 'chevron-down')
      $('blockquote', $aside).showHtml(@originalContents)

    false

  # Show how many times links have been clicked on
  showLinkCounts: ->
    if link_counts = @get('post.link_counts')
      link_counts.each (lc) =>
        if lc.clicks > 0
          @.$(".cooked a[href]").each ->
            link = $(this)
            if link.attr('href') == lc.url
              link.append("<span class='badge badge-notification clicks' title='clicks'>#{lc.clicks}</span>")

  # Add the quote controls to a post
  insertQuoteControls: ->

    @.$('aside.quote').each (i, e) =>
      $aside = $(e)

      @updateQuoteElements($aside, 'chevron-down')
      $title = $('.title', $aside)

      # Unless it's a full quote, allow click to expand
      unless $aside.data('full') or $title.data('has-quote-controls')
        $title.on 'click', (e) =>
          return true if $(e.target).is('a')
          @toggleQuote($aside)
        $title.data('has-quote-controls', true)

  didInsertElement: (e) ->

    $post = @.$()
    post = @get('post')

    # Do we want to scroll to this post now that we've inserted it?
    if postNumber = post.get('scrollToAfterInsert')
      Discourse.TopicView.scrollTo @get('post.topic_id'), postNumber

      if postNumber == post.get('post_number')
        $contents = $('.topic-body .contents', $post)
        originalCol = $contents.css('backgroundColor')
        $contents.css(backgroundColor: "#ffffcc").animate(backgroundColor: originalCol, 2500)

    @showLinkCounts()
    @get('screenTrack')?.track(@.$().prop('id'), @get('post.post_number'))

    # Add syntax highlighting
    Discourse.SyntaxHighlighting.apply($post)

    # If we're scrolling upwards, adjust the scroll position accordingly
    if scrollTo = @get('post.scrollTo')
      newSize = ($(document).height() - scrollTo.height) + scrollTo.top
      $('body').scrollTop(newSize)
      $('section.divider').addClass('fade')

    # Find all the quotes
    @insertQuoteControls()


