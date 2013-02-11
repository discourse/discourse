Discourse.Mention = (->

  localCache = {}

  cache = (name, valid) ->
    localCache[name] = valid
    return

  lookupCache = (name) ->
    localCache[name]

  lookup = (name, callback) ->
    cached = lookupCache(name)
    if cached == true || cached == false
      callback(cached)
      return false
    else
      $.get "/users/is_local_username", username: name, (r) ->
        cache(name,r.valid)
        callback(r.valid)
      return true

  load = (e) ->
    $elem = $(e)
    return if $elem.data('mention-tested')

    username = $elem.text()
    username = username.substr(1)
    loading = lookup username, (valid) ->
      if valid
        $elem.replaceWith("<a href='/users/#{username.toLowerCase()}' class='mention'>@#{username}</a>")
      else
        $elem.removeClass('mention-loading').addClass('mention-tested')

    $elem.addClass('mention-loading') if loading

  load: load
  lookup: lookup
  lookupCache: lookupCache
)()

