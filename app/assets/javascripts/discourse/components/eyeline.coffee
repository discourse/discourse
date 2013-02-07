#
#  Track visible elements on the screen
#
#   You can register for triggers on:
#     focusChanged: -> the top element we're focusing on
#     seenElement: -> if we've seen the element
#
class Discourse.Eyeline

  constructor: (@selector) ->

  # Call this whenever we want to consider what is currently being seen by the browser
  update: ->
    docViewTop = $(window).scrollTop()
    windowHeight = $(window).height()
    docViewBottom = docViewTop + windowHeight
    documentHeight = $(document).height()

    $elements = $(@selector)

    atBottom = false
    if bottomOffset = $elements.last().offset()
      atBottom = (bottomOffset.top <= docViewBottom) and (bottomOffset.top >= docViewTop)

    # Whether we've seen any elements in this search
    foundElement = false

    $results = $(@selector)
    $results.each (i, elem) =>
      $elem = $(elem)

      elemTop = $elem.offset().top
      elemBottom = elemTop + $elem.height()

      markSeen = false

      # It's seen if...
      # ...the element is vertically within the top and botom
      markSeen = true if ((elemTop <= docViewBottom) and (elemTop >= docViewTop))
      # ...the element top is above the top and the bottom is below the bottom (large elements)
      markSeen = true if ((elemTop <= docViewTop) and (elemBottom >= docViewBottom))
      # ...we're at the bottom and the bottom of the element is visible (large bottom elements)
      markSeen = true if atBottom and (elemBottom >= docViewTop)

      return true unless markSeen

      # If you hit the bottom we mark all the elements as seen. Otherwise, just the first one
      unless atBottom
        @trigger('saw', detail: $elem)
        @trigger('sawTop', detail: $elem) if i == 0
        return false

      @trigger('sawTop', detail: $elem) if i == 0
      @trigger('sawBottom', detail: $elem) if i == ($results.length - 1)

  # Call this when we know aren't loading any more elements. Mark the rest
  # as seen
  flushRest: ->
    $(@selector).each (i, elem) =>
      $elem = $(elem)
      @trigger('saw', detail: $elem)


RSVP.EventTarget.mixin(Discourse.Eyeline.prototype)
