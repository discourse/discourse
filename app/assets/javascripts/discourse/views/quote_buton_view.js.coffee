window.Discourse.QuoteButtonView = Discourse.View.extend
  classNames: ['quote-button']
  classNameBindings: ['hasBuffer']

  render: (buffer) -> buffer.push("quote reply")

  hasBuffer: (->
    return 'visible' if @present('controller.buffer')
    null
  ).property('controller.buffer')

  willDestroyElement: ->
    $(document).unbind("mousedown.quote-button")

  didInsertElement: ->
    # Clear quote button if they click elsewhere
    $(document).bind "mousedown.quote-button", (e) =>
     return if $(e.target).hasClass('quote-button')
     return if $(e.target).hasClass('create')
     @controller.mouseDown(e)
     @set('controller.lastSelected', @get('controller.buffer'))
     @set('controller.buffer', '')

  click: (e) ->
    @get('controller').quoteText(e)

