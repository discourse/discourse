window.Discourse.Draft = Discourse.Model.extend({})

Discourse.Draft.reopenClass

  clear: (key, sequence)->
    $.ajax
      type: 'DELETE'
      url: "/draft",
      data: {draft_key: key, sequence: sequence}
    # Discourse.KeyValueStore.remove("draft_#{key}")

  get: (key) ->
    promise = new RSVP.Promise
    $.ajax
      url: '/draft'
      data: {draft_key: key}
      dataType: 'json'
      success: (data) =>
        promise.resolve(data)
    promise

  getLocal: (key, current) ->
    return current

    # disabling for now to see if it helps with siracusa issue.

    local = Discourse.KeyValueStore.get("draft_#{key}")
    if !current || (local && local.length > current.length)
      local
    else
      current

  save: (key, sequence, data) ->
    promise = new RSVP.Promise()
    data = if typeof data == "string" then data else JSON.stringify(data)
    $.ajax
      type: 'POST'
      url: "/draft",
      data: {draft_key: key, data: data, sequence: sequence}
      success: ->
        # don't keep local
        # Discourse.KeyValueStore.remove("draft_#{key}")
        promise.resolve()
      error: ->
        # save local
        # Discourse.KeyValueStore.set(key: "draft_#{key}", value: data)
        promise.reject()
    promise



