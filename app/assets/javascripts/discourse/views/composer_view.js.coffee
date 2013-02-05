window.Discourse.ComposerView = window.Discourse.View.extend
  templateName: 'composer'
  elementId: 'reply-control'
  classNameBindings: ['content.creatingPrivateMessage:private-message',
                      'composeState',
                      'content.loading',
                      'content.editTitle',
                      'postMade',
                      'content.creatingTopic:topic',
                      'content.showPreview',
                      'content.hidePreview']

  composeState: (->
    state = @get('content.composeState')
    unless state
      state = Discourse.Composer.CLOSED
    state
  ).property('content.composeState')


  draftStatus: (->
    @$('.saving-draft').text(@get('content.draftStatus') || "")
  ).observes('content.draftStatus')

  # Disable fields when we're loading
  loadingChanged: (->
    if @get('loading')
      $('#wmd-input, #reply-title').prop('disabled', 'disabled')
    else
      $('#wmd-input, #reply-title').prop('disabled', '')
  ).observes('loading')

  postMade: (->
    return 'created-post' if @present('controller.createdPost')
    null
  ).property('content.createdPost')

  observeReplyChanges: (->

    return if @get('content.hidePreview')

    Ember.run.next null, =>
      if @editor
        @editor.refreshPreview()
        # if the caret is on the last line ensure preview scrolled to bottom
        caretPosition = Discourse.Utilities.caretPosition(@wmdInput[0])
        unless @wmdInput.val().substring(caretPosition).match /\n/
          $wmdPreview = $('#wmd-preview:visible')
          if $wmdPreview.length > 0
            $wmdPreview.scrollTop($wmdPreview[0].scrollHeight)


  ).observes('content.reply', 'content.hidePreview')

  willDestroyElement: ->
    $('body').off 'keydown.composer'
  
  resize: (->
    # this still needs to wait on animations, need a clean way to do that
    Em.run.next null, =>
      replyControl = $('#reply-control')
      h = replyControl.height() || 0
      $('.topic-area').css('padding-bottom', "#{h}px")
  ).observes('content.composeState')

  didInsertElement: ->

    # Delegate ESC to the composer
    $('body').on 'keydown.composer', (e) =>
      @get('controller').hitEsc() if e.which == 27

    replyControl = $('#reply-control')
    replyControl.DivResizer(resize: @resize)
    Discourse.TransitionHelper.after(replyControl, @resize)

  click: ->
    @get('controller').click()

  # Called after the preview renders. Debounced for performance
  afterRender: Discourse.debounce(->
    $wmdPreview = $('#wmd-preview')
    return unless ($wmdPreview.length > 0)
    Discourse.SyntaxHighlighting.apply($wmdPreview)
    refresh = @get('controller.content.post.id') isnt undefined
    $('a.onebox', $wmdPreview).each (i, e) => Discourse.Onebox.load(e, refresh)
    $('span.mention', $wmdPreview).each (i, e) => Discourse.Mention.load(e, refresh)
  , 100)

  cancelUpload: ->
    # TODO

  initEditor: ->

    # not quite right, need a callback to pass in, meaning this gets called once, 
    #    but if you start replying to another topic it will get the avatars wrong
    @wmdInput = $wmdInput = $('#wmd-input')
    return if $wmdInput.length == 0 || $wmdInput.data('init') == true
    
    Discourse.ComposerView.trigger("initWmdEditor")
    
    template = Handlebars.compile("<div class='autocomplete'>
   <ul>
      {{#each options}}
          <li>
            <a href='#'>{{avatar this imageSize=\"tiny\"}} <span class='username'>{{this.username}}</span> <span class='name'>{{this.name}}</span></a>
          </li>
      {{/each}}
   </ul>
</div>")

    transformTemplate = Handlebars.compile("{{avatar this imageSize=\"tiny\"}} {{this.username}}")

    $wmdInput.data('init', true)
    $wmdInput.autocomplete
      template: template
      dataSource: (term,callback) =>
        Discourse.UserSearch.search
          term: term,
          callback: callback,
          topicId: @get('controller.controllers.topic.content.id')
      key: "@"
      transformComplete: (v) ->
        v.username

    selected = []
    $('#private-message-users').val(@get('content.targetUsernames')).autocomplete
      template: template
      dataSource: (term, callback) ->
        Discourse.UserSearch.search
          term: term,
          callback: callback,
          exclude: selected
      onChangeItems: (items) =>
        items = $.map items, (i) -> if i.username then i.username else i
        @set('content.targetUsernames', items.join(","))
        selected = items
      transformComplete: transformTemplate
      reverseTransform: (i) -> {username: i}

    topic = @get('topic')
    @editor = editor = new Markdown.Editor(Discourse.Utilities.markdownConverter(
      lookupAvatar: (username) ->
        Discourse.Utilities.avatarImg(username: username, size: 'tiny')
    ))

    $uploadTarget = $('#reply-control')
    @editor.hooks.insertImageDialog = (callback) =>
      callback(null)
      @get('controller.controllers.modal').show(Discourse.ImageSelectorView.create(composer: @, uploadTarget: $uploadTarget))
      true
    @editor.hooks.onPreviewRefresh = => @afterRender()
    @editor.run()
    @set('editor', @editor)
  
    @loadingChanged()

    saveDraft = Discourse.debounce((=> @get('controller').saveDraft()),2000)

    $wmdInput.keyup =>
      saveDraft()
      return true

    $('#reply-title').keyup =>
      saveDraft()
      return true

    # In case it's still bound somehow    
    $uploadTarget.fileupload('destroy')

    # Add the upload action
    $uploadTarget.fileupload
      url: '/uploads'
      dataType: 'json'
      timeout: 20000
      formData:
        topic_id: 1234
      paste: (e, data) =>
        if data.files.length > 0
          @set('loadingImage', true)
          @set('uploadProgress', 0)
        true
      drop: (e, data)=>
        if e.originalEvent.dataTransfer.files.length == 1
          @set('loadingImage', true)
          @set('uploadProgress', 0)

      progressall:(e,data)=>
        progress = parseInt(data.loaded / data.total * 100, 10)
        @set('uploadProgress', progress)

      done: (e, data) =>
        @set('loadingImage', false)
        upload = data.result
        html = "<img src='#{upload.url}' width='#{upload.width}' height='#{upload.height}'>"
        @addMarkdown(html)

      fail: (e, data) =>
        bootbox.alert Em.String.i18n('post.errors.upload')
        @set('loadingImage', false)


    # I hate to use Em.run.later, but I don't think there's a way of waiting for a CSS transition 
    # to finish.
    Em.run.later($, (=>
      replyTitle = $('#reply-title')

      @resize()
      
      if replyTitle.length
        replyTitle.putCursorAtEnd()
      else
        $wmdInput.putCursorAtEnd()
    )
    , 300)

  addMarkdown: (text)->
    ctrl = $('#wmd-input').get(0)
    caretPosition = Discourse.Utilities.caretPosition(ctrl)

    current = @get('content.reply')
    @set('content.reply', current.substring(0, caretPosition) + text +  current.substring(caretPosition, current.length))
    Em.run.next =>
      Discourse.Utilities.setCaretPosition(ctrl, caretPosition + text.length)

  # Uses javascript to get the image sizes from the preview, if present
  imageSizes: ->
    result = {}

    $('#wmd-preview img').each (i, e) ->
      $img = $(e)
      result[$img.prop('src')] = {width: $img.width(), height: $img.height()}
    result

  childDidInsertElement: (e)->
    @initEditor()


# not sure if this is the right way, keeping here for now, we could use a mixin perhaps
Discourse.NotifyingTextArea = Ember.TextArea.extend

  placeholder: (->
    Em.String.i18n(@get('placeholderKey'))
  ).property('placeholderKey')
  
  didInsertElement: ->
    @get('parent').childDidInsertElement(@)

RSVP.EventTarget.mixin(Discourse.ComposerView)
