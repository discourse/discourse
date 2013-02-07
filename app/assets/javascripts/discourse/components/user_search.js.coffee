cache = {}
cacheTopicId = null
cacheTime = null

doSearch = (term,topicId,success)->
  $.ajax
    url: '/users/search/users'
    dataType: 'JSON'
    data: {term: term, topic_id: topicId}
    success: (r)->
      cache[term] = r
      cacheTime = new Date()
      success(r)

debouncedSearch = Discourse.debounce(doSearch, 200)

window.Discourse.UserSearch =
  search: (options) ->

    term = options.term || ""
    callback = options.callback
    exclude = options.exclude || []
    topicId = options.topicId
    limit = options.limit || 5

    throw "missing callback" unless callback

    #TODO site setting for allowed regex in username ?
    if term.match(/[^a-zA-Z0-9\_\.]/)
      callback([])
      return true

    cache = {} if (new Date() - cacheTime) > 30000
    cache = {} if cacheTopicId != topicId
    cacheTopicId = topicId

    success = (r)->
      result = []
      r.users.each (u)->
        result.push(u) if exclude.indexOf(u.username) == -1
        return false if result.length > limit
        true
      callback(result)

    if cache[term]
      success(cache[term])
    else
      debouncedSearch(term, topicId, success)
    true


