window.Discourse.ComposerController = Ember.Controller.extend Discourse.Presence,

  needs: ['modal', 'topic']

  togglePreview: ->
    @get('content').togglePreview()

  # Import a quote from the post
  importQuote: ->
    @get('content').importQuote()

  appendText: (text) ->
    c = @get('content')
    c.appendText(text) if c

  save: ->
    composer = @get('content')
    composer.set('disableDrafts', true)
    composer.save(imageSizes: @get('view').imageSizes())
      .then (opts) =>
        opts = opts || {}
        @close()
        Discourse.routeTo(opts.post.get('url'))
      , (error) =>
        composer.set('disableDrafts', false)
        bootbox.alert error
      
  saveDraft: ->
    model = @get('content')
    model.saveDraft() if model

  # Open the reply view
  # 
  #  opts:
  #    action   - The action we're performing: edit, reply or createTopic  
  #    post     - The post we're replying to, if present
  #    topic   - The topic we're replying to, if present
  #    quote    - If we're opening a reply from a quote, the quote we're making  
  #
  open: (opts={}) ->
    opts.promise = promise = opts.promise || new RSVP.Promise

    unless opts.draftKey
      alert("composer was opened without a draft key")
      throw "composer opened without a proper draft key"

    # ensure we have a view now, without it transitions are going to be messed
    view = @get('view')
    unless view
      view = Discourse.ComposerView.create
        controller: @
      view.appendTo($('#main'))
      @set('view', view)
      # the next runloop is too soon, need to get the control rendered and then 
      #  we need to change stuff, otherwise css animations don't kick in
      Em.run.next =>
        Em.run.next =>
          @open(opts)
      return promise

    composer = @get('content')

    if composer && opts.draftKey != composer.draftKey && composer.composeState == Discourse.Composer.DRAFT
      @close()
      composer = null

    if composer && !opts.tested && composer.wouldLoseChanges()
      if composer.composeState == Discourse.Composer.DRAFT && composer.draftKey == opts.draftKey && composer.action == opts.action
        composer.set('composeState', Discourse.Composer.OPEN)
        promise.resolve()
        return promise
      else
        opts.tested = true
        @cancel(( => @open(opts) ),( => promise.reject())) unless opts.ignoreIfChanged
        return promise


    # we need a draft sequence, without it drafts are bust
    if opts.draftSequence == undefined
      Discourse.Draft.get(opts.draftKey).then (data)=>
        opts.draftSequence = data.draft_sequence
        opts.draft = data.draft
        @open(opts)
      return promise


    if opts.draft
      composer = Discourse.Composer.loadDraft(opts.draftKey, opts.draftSequence, opts.draft)
      composer?.set('topic', opts.topic)
      
    composer = composer || Discourse.Composer.open(opts)

    @set('content', composer)
    @set('view.content', composer)
    promise.resolve()
    return promise

  wouldLoseChanges: ->
    composer = @get('content')
    composer && composer.wouldLoseChanges()

  # View a new reply we've made
  viewNewReply: ->
    Discourse.routeTo(@get('createdPost.url'))
    @close()
    false

  destroyDraft: ->
    key = @get('content.draftKey')
    Discourse.Draft.clear(key, @get('content.draftSequence')) if key

  cancel: (success, fail) ->
    if @get('content.hasMetaData') || ((@get('content.reply') || "") != (@get('content.originalText') || ""))
      bootbox.confirm Em.String.i18n("post.abandon"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), (result) =>
        if result
          @destroyDraft()
          @close()
          success() if typeof success == "function"
        else
          fail() if typeof fail == "function"
    else
      # it is possible there is some sort of crazy draft with no body ... just give up on it 
      @destroyDraft()
      @close()
      success() if typeof success == "function"

    return

  click: ->
    if @get('content.composeState') == Discourse.Composer.DRAFT
      @set('content.composeState', Discourse.Composer.OPEN)
    false

  shrink: ->
    if @get('content.reply') == @get('content.originalText') then @close() else @collapse()
  
  collapse: ->
    @saveDraft()
    @set('content.composeState', Discourse.Composer.DRAFT)

  close: ->
    @set('content', null)
    @set('view.content', null)

  closeIfCollapsed: ->
    if @get('content.composeState') == Discourse.Composer.DRAFT
      @close()

  closeAutocomplete: ->
    $('#wmd-input').autocomplete(cancel: true)

  # Toggle the reply view
  toggle: ->
    @closeAutocomplete()

    switch @get('content.composeState')
      when Discourse.Composer.OPEN
        if @blank('content.reply') and @blank('content.title') then @close() else @shrink()
      when Discourse.Composer.DRAFT
        @set('content.composeState', Discourse.Composer.OPEN)
      when Discourse.Composer.SAVING
        @close()

    false

  # ESC key hit
  hitEsc: ->
    @shrink() if @get('content.composeState') == @OPEN
  

  showOptions: ->
    @get('controllers.modal')?.show(Discourse.ArchetypeOptionsModalView.create(archetype: @get('content.archetype'), metaData: @get('content.metaData')))

