Discourse.AceEditorView = window.Discourse.View.extend
  mode: 'css'
  classNames: ['ace-wrapper']

  contentChanged:(->
    if @editor && !@skipContentChangeEvent
      @editor.getSession().setValue(@get('content'))
  ).observes('content')
  
  render: (buffer) ->
    buffer.push("<div class='ace'>")
    buffer.push(Handlebars.Utils.escapeExpression(@get('content'))) if @get('content')
    buffer.push("</div>")

  willDestroyElement: ->
    if @editor
      @editor.destroy()
      @editor = null

  didInsertElement: ->
    initAce = =>
      @editor = ace.edit(@$('.ace')[0])
      @editor.setTheme("ace/theme/chrome")
      @editor.setShowPrintMargin(false)
      @editor.getSession().setMode("ace/mode/#{@get('mode')}")
      @editor.on "change", (e)=>
        # amending stuff as you type seems a bit out of scope for now - can revisit after launch
        # changes = @get('changes')
        # unless changes
        #   changes = []
        #   @set('changes', changes)
        # changes.push e.data

        @skipContentChangeEvent = true
        @set('content', @editor.getSession().getValue())
        @skipContentChangeEvent = false
    if window.ace
      initAce()
    else
      $LAB.script('http://d1n0x3qji82z53.cloudfront.net/src-min-noconflict/ace.js').wait initAce


