# CSS transitions are a PITA, often we need to queue some js after a transition, this helper ensures 
#  it happens after the transition
#

# SO: http://stackoverflow.com/questions/9943435/css3-animation-end-techniques
dummy = document.createElement("div")
eventNameHash =
  webkit: "webkitTransitionEnd"
  Moz: "transitionend"
  O: "oTransitionEnd"
  ms: "MSTransitionEnd"

transitionEnd = (_getTransitionEndEventName = ->
  retValue = "transitionend"
  Object.keys(eventNameHash).some (vendor) ->
    if vendor + "TransitionProperty" of dummy.style
      retValue = eventNameHash[vendor]
      true

  retValue
)()

window.Discourse.TransitionHelper =
  after: (element, callback) ->
    $(element).on(transitionEnd, callback)
