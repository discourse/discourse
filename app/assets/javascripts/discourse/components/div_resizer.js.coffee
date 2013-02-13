#based off text area resizer by Ryan O'Dell : http://plugins.jquery.com/misc/textarea.js
(($) ->

  div = undefined
  originalPos = undefined
  originalDivHeight = undefined
  lastMousePos = 0
  min = 230
  grip = undefined
  wrappedEndDrag = undefined
  wrappedPerformDrag = undefined

  startDrag = (e,opts) ->
    div = $(e.data.el)
    div.addClass('clear-transitions')
    div.blur()
    lastMousePos = mousePosition(e).y
    originalPos = lastMousePos
    originalDivHeight = div.height()
    wrappedPerformDrag  = ( ->
      (e) -> performDrag(e,opts)
    )()
    wrappedEndDrag = ( ->
      (e) -> endDrag(e,opts)
    )()
    $(document).mousemove(wrappedPerformDrag).mouseup wrappedEndDrag
    false
  performDrag = (e,opts) ->
    thisMousePos = mousePosition(e).y
    size = originalDivHeight + (originalPos - thisMousePos)
    lastMousePos = thisMousePos
    size = Math.min(size, $(window).height())
    size = Math.max(min, size)
    div.height size + "px"
    endDrag e,opts if size < min
    false
  endDrag = (e,opts) ->
    $(document).unbind("mousemove", wrappedPerformDrag).unbind "mouseup", wrappedEndDrag
    div.removeClass('clear-transitions')
    div.focus()
    opts.resize() if opts.resize
    div = null
  mousePosition = (e) ->
    x: e.clientX + document.documentElement.scrollLeft
    y: e.clientY + document.documentElement.scrollTop

  $.fn.DivResizer = (opts) ->
    @each ->
      div = $(this)
      return if (div.hasClass("processed"))

      div.addClass("processed")
      staticOffset = null

      start = ->
        (e) -> startDrag(e,opts)

      grippie = div.prepend("<div class='grippie'></div>").find('.grippie').bind("mousedown",
        el: this
      , start())
) jQuery

