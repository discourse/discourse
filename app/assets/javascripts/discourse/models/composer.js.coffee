# The status the compose view can have
CLOSED = 'closed'
SAVING = 'saving'
OPEN = 'open'
DRAFT = 'draft'

# The actions the composer can take
CREATE_TOPIC = 'createTopic'
PRIVATE_MESSAGE = 'privateMessage'
REPLY = 'reply'
EDIT = 'edit'

REPLY_AS_NEW_TOPIC_KEY = "reply_as_new_topic"

window.Discourse.Composer = Discourse.Model.extend
  init: ->
    @_super()
    val = (Discourse.KeyValueStore.get('composer.showPreview') or 'true')
    @set('showPreview', val is 'true')
    @set 'archetypeId', Discourse.get('site.default_archetype')
  
  archetypesBinding: 'Discourse.site.archetypes'
  
  creatingTopic: (-> @get('action') == CREATE_TOPIC ).property('action')
  creatingPrivateMessage: (-> @get('action') == PRIVATE_MESSAGE ).property('action')
  editingPost: (-> @get('action') == EDIT).property('action')
  viewOpen: (-> @get('composeState') == OPEN ).property('composeState')
  
  archetype: (->
    @get('archetypes').findProperty('id', @get('archetypeId'))
  ).property('archetypeId')

  archetypeChanged: (->
    @set('metaData', Em.Object.create())
  ).observes('archetype')

  editTitle: (->
    return true if @get('creatingTopic') || @get('creatingPrivateMessage')
    return true if @get('editingPost') and @get('post.post_number') == 1
    false
  ).property('editingPost', 'creatingTopic', 'post.post_number')


  togglePreview: ->
    @toggleProperty('showPreview')
    Discourse.KeyValueStore.set(key: 'showPreview', value: @get('showPreview'))
  
  # Import a quote from the post
  importQuote: ->
    post = @get('post')
    unless post
      posts = @get('topic.posts')
      post = posts[0] if posts && posts.length > 0

    if post
      @set('loading', true)
      Discourse.Post.load post.get('id'), (result) =>
        quotedText = Discourse.BBCode.buildQuoteBBCode(post, result.get('raw'))
        @appendText(quotedText)
        @set('loading', false)

  appendText: (text)->
    @set 'reply', (@get('reply') || '') + text

  # Determine the appropriate title for this action
  actionTitle: (->
    topic = @get('topic')
    postNumber = @get('post.post_number')

    if topic
      postLink = "<a href='#{topic.get('url')}/#{postNumber}'>post #{postNumber}</a>"

    switch @get('action')
      when PRIVATE_MESSAGE
        Em.String.i18n('topic.private_message')
      when CREATE_TOPIC
        Em.String.i18n('topic.create_long')
      when REPLY
        if @get('post')
          replyAvatar = Discourse.Utilities.avatarImg(
            username: @get('post.username'),
            size: 'tiny'
          )
          Em.String.i18n('post.reply', link: postLink, replyAvatar: replyAvatar, username: @get('post.username'))
        else if topic
          topicLink = "<a href='#{topic.get('url')}'> #{Handlebars.Utils.escapeExpression(topic.get('title'))}</a>"
          Em.String.i18n('post.reply_topic', link: topicLink)
      when EDIT
        Em.String.i18n('post.edit', link: postLink)
  ).property('action', 'post', 'topic', 'topic.title')

  toggleText: (->
    return Em.String.i18n('composer.hide_preview') if @get('showPreview')
    Em.String.i18n('composer.show_preview')
  ).property('showPreview')

  hidePreview: (-> not @get('showPreview') ).property('showPreview')
  
  # Whether to disable the post button
  cantSubmitPost: (->

    # Can't submit while loading
    return true if @get('loading')

    # Title is required on new posts
    if @get('creatingTopic')
      return true if @blank('title')
      return true if @get('title').trim().length < Discourse.SiteSettings.min_topic_title_length

    # Otherwise just reply is required
    return true if @blank('reply')
    return true if @get('reply').trim().length < Discourse.SiteSettings.min_post_length

    false
  ).property('reply', 'title', 'creatingTopic', 'loading')
  
  # The text for the save button
  saveText: (->
    switch @get('action')
      when EDIT then Em.String.i18n('composer.save_edit')
      when REPLY then Em.String.i18n('composer.reply')
      when CREATE_TOPIC then Em.String.i18n('composer.create_topic')
      when PRIVATE_MESSAGE then Em.String.i18n('composer.create_pm')
  ).property('action')

  hasMetaData: (->
    metaData = @get('metaData')
    return false unless @get('metaData')
    return Em.empty(Em.keys(@get('metaData')))
  ).property('metaData')

 
  wouldLoseChanges: ()->
    @get('reply') != @get('originalText') # TODO title check as well

  # Open a composer
  # 
  #  opts:
  #    action   - The action we're performing: edit, reply or createTopic  
  #    post     - The post we're replying to, if present
  #    topic   - The topic we're replying to, if present
  #    quote    - If we're opening a reply from a quote, the quote we're making  
  #
  open: (opts={}) ->
    
    @set('loading', false)

    topicId = opts.topic.get('id') if opts.topic
    replyBlank = (@get("reply") || "") == ""
    if !replyBlank && (opts.action != @get('action') || ((opts.reply || opts.action == @EDIT) && @get('reply') != @get('originalText'))) && !opts.tested
      opts.tested = true
      @cancel(=> @open(opts))
      return
    
    @set 'draftKey', opts.draftKey
    @set 'draftSequence', opts.draftSequence
    throw 'draft key is required' unless opts.draftKey
    throw 'draft sequence is required' if opts.draftSequence == null

    @set 'composeState', opts.composerState || OPEN
    @set 'action', opts.action
    @set 'topic', opts.topic

    @set 'targetUsernames', opts.usernames

    if opts.post
      @set 'post', opts.post
      @set 'topic', opts.post.get('topic') unless @get('topic')

    @set('categoryName', opts.categoryName || @get('topic.category.name'))
    @set('archetypeId', opts.archetypeId || Discourse.get('site.default_archetype'))
    @set('metaData', if opts.metaData then Em.Object.create(opts.metaData) else null)
    @set('reply', opts.reply || @get("reply") || "")

    if opts.postId
      @set('loading', true)
      Discourse.Post.load opts.postId, (result) =>
        @set('post', result)
        @set('loading', false)
  
    # If we are editing a post, load it.
    if opts.action == EDIT and opts.post
      @set 'title', @get('topic.title')
      @set('loading', true)
      Discourse.Post.load opts.post.get('id'), (result) =>
        @set 'reply', result.get('raw')
        @set('originalText', @get('reply'))
        @set('loading', false)
    
    if opts.title
      @set('title', opts.title)
    if opts.draft
      @set('originalText', '')
    else if opts.reply
      @set('originalText', @get('reply'))

    false

  
  save: (opts)->
    if @get('editingPost')
      @editPost(opts)
    else
      @createPost(opts)

  # When you edit a post
  editPost: (opts)->
    promise = new RSVP.Promise

    post = @get('post')

    oldCooked = post.get('cooked')

    # Update the title if we've changed it
    if @get('title') and post.get('post_number') == 1
      topic = @get('topic')
      topic.set('title', @get('title'))
      topic.set('categoryName', @get('categoryName'))
      topic.save()

    post.set('raw', @get('reply'))
    post.set('imageSizes', opts.imageSizes)
    post.set('cooked', $('#wmd-preview').html())
    @set('composeState', CLOSED)

    post.save (savedPost) =>
      posts = @get('topic.posts')
      # perhaps our post came from elsewhere eg. draft
      idx = -1
      postNumber = post.get('post_number')
      posts.each (p,i)->
        idx = i if p.get('post_number') == postNumber
    
      if idx > -1
        savedPost.set('topic', @get('topic'))
        posts.replace(idx, 1, [savedPost])
        promise.resolve(post: post)
        @set('topic.draft_sequence', savedPost.draft_sequence)

    , (error) =>
      errors = jQuery.parseJSON(error.responseText).errors
      promise.reject(errors[0])
      post.set('cooked', oldCooked)
      @set('composeState', OPEN)

    promise
      

  # Create a new Post
  createPost: (opts)->
    promise = new RSVP.Promise
    post = @get('post')
    topic = @get('topic')

    createdPost = Discourse.Post.create
      raw: @get('reply')
      title: @get('title')
      category: @get('categoryName')
      topic_id: @get('topic.id')
      reply_to_post_number: if post then post.get('post_number') else null
      imageSizes: opts.imageSizes
      post_number: @get('topic.highest_post_number') + 1
      cooked: $('#wmd-preview').html()
      reply_count: 0
      display_username: Discourse.get('currentUser.name')
      username: Discourse.get('currentUser.username')
      metaData: @get('metaData')
      archetype: @get('archetypeId')
      post_type: Discourse.Post.REGULAR_TYPE
      target_usernames: @get('targetUsernames')
      actions_summary: Em.A()
      yours: true
      newPost: true

    addedToStream = false

    # If we're in a topic, we can append the post instantly.    
    if topic
      # Increase the reply count        
      if post
        post.set('reply_count', (post.get('reply_count') || 0) + 1)

        # Supress replies
        if (post.get('reply_count') == 1 && createdPost.get('cooked').length < Discourse.SiteSettings.max_length_show_reply)
          post.set('replyFollowing', true)

        post.set('reply_below_post_number', createdPost.get('post_number'))

      topic.set('posts_count', topic.get('posts_count') + 1)

      # Update last post
      topic.set('last_posted_at', new Date())
      topic.set('highest_post_number', createdPost.get('post_number'))
      topic.set('last_poster', Discourse.get('currentUser'))

      # Set the topic view for the new post
      createdPost.set('topic', topic)
      createdPost.set('created_at', new Date())

      # If we're near the end of the topic, load new posts
      lastPost = topic.posts.last()
      
      if lastPost
        diff = topic.get('highest_post_number') - lastPost.get('post_number')

        # If the new post is within a threshold of the end of the topic, 
        # add it and scroll there instead of adding the link.
        if diff < 5
          createdPost.set('scrollToAfterInsert', createdPost.get('post_number'))
          topic.pushPosts([createdPost])
          addedToStream = true
 
    # Save callback
    createdPost.save (result) =>
      addedPost = false
      saving = true
      createdPost.updateFromSave(result)
      if topic
        # It's no longer a new post
        createdPost.set('newPost', false)
        topic.set('draft_sequence', result.draft_sequence)
      else
        # We created a new topic, let's show it.
        @set('composeState', CLOSED)
        saving = false
        
      @set('reply', '')
      @set('createdPost', createdPost)

      if addedToStream
        @set('composeState', CLOSED)
      else if saving
        @set('composeState', SAVING)

      promise.resolve(post: result)

    , (error) =>
      topic.posts.removeObject(createdPost) if topic
      errors = jQuery.parseJSON(error.responseText).errors
      promise.reject(errors[0])
      @set('composeState', OPEN)
    promise

  saveDraft: ->

    return if @disableDrafts

    data =
      reply: @get("reply"),
      action: @get("action"),
      title: @get("title"),
      categoryName: @get("categoryName"),
      postId: @get("post.id"),
      archetypeId: @get('archetypeId')
      metaData: @get('metaData')
      usernames: @get('targetUsernames')
      
    @set('draftStatus', Em.String.i18n('composer.saving_draft_tip'))
    Discourse.Draft.save(@get('draftKey'), @get('draftSequence'), data)
      .then(
        (=> @set('draftStatus', Em.String.i18n('composer.saved_draft_tip'))),
        (=> @set('draftStatus', 'drafts offline'))
        # (=> @set('draftStatus', Em.String.i18n('composer.saved_local_draft_tip')))
      )

  resetDraftStatus: (->
    @set('draftStatus', null)
  ).observes('reply','title')


  blank: (prop)->
    p = @get(prop)
    !(p && p.length > 0)


Discourse.Composer.reopenClass

  open: (opts) ->
    composer = Discourse.Composer.create()
    composer.open(opts)
    composer

  loadDraft: (draftKey, draftSequence, draft, topic) ->

    try
      draft = JSON.parse(draft) if draft && typeof draft == 'string'
    catch error
      draft = null
      Discourse.Draft.clear(draftKey, draftSequence)
    if draft && ((draft.title && draft.title != '') || (draft.reply && draft.reply != ''))
      composer = @open
        draftKey: draftKey
        draftSequence: draftSequence
        topic: topic
        action: draft.action
        title: draft.title
        categoryName: draft.categoryName
        postId: draft.postId
        archetypeId: draft.archetypeId
        reply: draft.reply
        metaData: draft.metaData
        usernames: draft.usernames
        draft: true
        composerState: DRAFT
    composer

  # The status the compose view can have
  CLOSED: CLOSED
  SAVING: SAVING
  OPEN: OPEN
  DRAFT: DRAFT

  # The actions the composer can take
  CREATE_TOPIC: CREATE_TOPIC
  PRIVATE_MESSAGE: PRIVATE_MESSAGE
  REPLY: REPLY
  EDIT: EDIT

  # Draft key
  REPLY_AS_NEW_TOPIC_KEY: REPLY_AS_NEW_TOPIC_KEY  


