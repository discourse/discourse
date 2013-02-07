# key value store
#

window.Discourse.KeyValueStore = (->
  initialized = false
  context = ""

  init: (ctx,messageBus) ->
    initialized = true
    context = ctx

  abandonLocal: ->
    return unless localStorage && initialized
    i=localStorage.length-1
    while i >= 0
      k = localStorage.key(i)
      localStorage.removeItem(k) if k.substring(0, context.length) == context
      i--
    return true

  remove: (key)->
    localStorage.removeItem(context + key)

  set: (opts)->
    return false unless localStorage && initialized
    localStorage[context + opts["key"]] = opts["value"]


  get: (key)->
    return null unless localStorage
    localStorage[context + key]
)()

