# Use this mixin if you want to be notified every time the user scrolls the window
window.Discourse.Scrolling = Em.Mixin.create

  bindScrolling: ->

    onScroll = Discourse.debounce(=>
      @scrolled()
    , 100)

    $(document).bind 'touchmove.discourse', onScroll
    $(window).bind 'scroll.discourse', onScroll
  unbindScrolling: ->
    $(window).unbind 'scroll.discourse'
    $(document).unbind 'touchmove.discourse'

