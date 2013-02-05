window.Discourse.debounce = (func, wait, trickle) ->
  timeout = null
  return ->
    context = @
    args = arguments
    later = ->
      timeout = null
      func.apply(context, args)

    if timeout != null && trickle
      # already queued, let it through
      return

    if typeof wait == "function"
      currentWait = wait()
    else
      currentWait = wait

    clearTimeout(timeout) if timeout
    timeout = setTimeout(later, currentWait)
