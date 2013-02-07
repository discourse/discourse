window.Discourse.FlaggedPost = Discourse.Post.extend
  flaggers: (->
    r = []
    @post_actions.each (a)=>
      r.push(@userLookup[a.user_id])
    r
  ).property()

  messages: (->
    r = []
    @post_actions.each (a)=>
      if a.message
        r.push
          user: @userLookup[a.user_id]
          message: a.message
    r
  ).property()
    
  lastFlagged: (->
    @post_actions[0].created_at
  ).property()

  user: (->
    @userLookup[@user_id]
  ).property()

  topicHidden: (->
    @get('topic_visible') == 'f'
  ).property('topic_hidden')

  deletePost: ->
    promise = new RSVP.Promise()
    if @get('post_number') == "1"
      $.ajax "/t/#{@topic_id}",
        type: 'DELETE'
        cache: false
        success: ->
          promise.resolve()
        error: (e)->
          promise.reject()
    else
      $.ajax "/posts/#{@id}",
        type: 'DELETE'
        cache: false
        success: ->
          promise.resolve()
        error: (e)->
          promise.reject()

  clearFlags: ->
    promise = new RSVP.Promise()
    $.ajax "/admin/flags/clear/#{@id}",
      type: 'POST'
      cache: false
      success: ->
        promise.resolve()
      error: (e)->
        promise.reject()

    promise

  hiddenClass: (->
    "hidden-post" if @get('hidden') == "t"
  ).property()


window.Discourse.FlaggedPost.reopenClass

  findAll: (filter) ->
    result = Em.A()
    $.ajax
      url: "/admin/flags/#{filter}.json"
      success: (data) ->
        userLookup = {}
        data.users.each (u) -> userLookup[u.id] = Discourse.User.create(u)
        data.posts.each (p) ->
          f = Discourse.FlaggedPost.create(p)
          f.userLookup = userLookup
          result.pushObject(f)
    result

