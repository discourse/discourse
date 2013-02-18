Discourse.Onebox = (->
  # for now it only stores in a var, in future we can change it so it uses localStorage,
  #  trouble with localStorage is that expire semantics need some thinking

  #cacheKey = "__onebox__"
  localCache = {}

  cache = (url, contents) ->
    localCache[url] = contents

    #if localStorage && localStorage.setItem
    #  localStorage.setItme
    null

  lookupCache = (url) ->
    cached = localCache[url]
    if cached && cached.then # its a promise
      null
    else
      cached

  lookup = (url, refresh, callback) ->
    cached = localCache[url]
    cached = null if refresh && cached && !cached.then
    if cached
      if cached.then
        cached.then(callback(lookupCache(url)))
      else
        callback(cached)
      return false
    else
      cache(url, $.get "/onebox", url: url, refresh: refresh, (html) ->
        cache(url,html)
        callback(html)
      )
      return true

  load = (e, refresh=false) ->

    url = e.href
    $elem = $(e)
    return if $elem.data('onebox-loaded')

    loading = lookup url, refresh, (html) ->
      $elem.removeClass('loading-onebox')
      $elem.data('onebox-loaded')
      return unless html
      return unless html.trim().length > 0
      $elem.replaceWith(html)

    $elem.addClass('loading-onebox') if loading

  load: load
  lookup: lookup
  lookupCache: lookupCache
)()

