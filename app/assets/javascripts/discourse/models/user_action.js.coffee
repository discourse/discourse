window.Discourse.UserAction = Discourse.Model.extend
  postUrl:(->
    Discourse.Utilities.postUrl(@get('slug'), @get('topic_id'), @get('post_number'))
  ).property()
  
  replyUrl: (->
    Discourse.Utilities.postUrl(@get('slug'), @get('topic_id'), @get('reply_to_post_number'))
  ).property()

  isPM: (->
    a = @get('action_type')
    a == Discourse.UserAction.NEW_PRIVATE_MESSAGE || a == Discourse.UserAction.GOT_PRIVATE_MESSAGE
  ).property()
  
  isPostAction: (->
    a = @get('action_type')
    a == Discourse.UserAction.RESPONSE || a == Discourse.UserAction.POST || a == Discourse.UserAction.NEW_TOPIC
  ).property()

  addChild: (action)->
    groups = @get("childGroups")
    unless groups
      groups =
        likes: Discourse.UserActionGroup.create(icon: "icon-heart")
        stars: Discourse.UserActionGroup.create(icon: "icon-star")
        edits: Discourse.UserActionGroup.create(icon: "icon-pencil")
        bookmarks: Discourse.UserActionGroup.create(icon: "icon-bookmark")

    @set("childGroups", groups)

    ua = Discourse.UserAction
    bucket = switch action.action_type
      when ua.LIKE,ua.WAS_LIKED then "likes"
      when ua.STAR then "stars"
      when ua.EDIT then "edits"
      when ua.BOOKMARK then "bookmarks"
    
    current = groups[bucket]
    current.push(action) if current
    return

  children:(->
    g = @get("childGroups")
    rval = []
    if g
      rval = [g.likes, g.stars, g.edits, g.bookmarks].filter((i) -> i.get("items") && i.get("items").length > 0)
    rval
  ).property("childGroups")

  switchToActing: ->
    @set('username', @get('acting_username'))
    @set('avatar_template', @get('acting_avatar_template'))
    @set('name', @get('acting_name'))

window.Discourse.UserAction.reopenClass
  collapseStream: (stream) ->
    collapse = [@LIKE, @WAS_LIKED, @STAR, @EDIT, @BOOKMARK]
    uniq = {}
    collapsed = Em.A()
    pos = 0
    stream.each (item)->
      key = "#{item.topic_id}-#{item.post_number}"

      found = uniq[key]

      if found == undefined
        if collapse.indexOf(item.action_type) >= 0
          current = Discourse.UserAction.create(item)
          current.set('action_type',null)
          current.set('description',null)
          item.switchToActing()
          current.addChild(item)
        else
          current = item
        uniq[key] = pos
        collapsed[pos] = current
        pos += 1
      else
        if collapse.indexOf(item.action_type) >= 0
          item.switchToActing()
          collapsed[found].addChild(item)
        else
          collapsed[found].set('action_type', item.get('action_type'))
          collapsed[found].set('description', item.get('description'))


    collapsed
      

  # in future we should be sending this through from the server
  LIKE: 1
  WAS_LIKED: 2
  BOOKMARK: 3
  NEW_TOPIC: 4
  POST: 5
  RESPONSE: 6
  MENTION: 7
  QUOTE: 9
  STAR: 10
  EDIT: 11
  NEW_PRIVATE_MESSAGE: 12
  GOT_PRIVATE_MESSAGE: 13

window.Discourse.UserAction.reopenClass
  statGroups: (->
    g = {}
    g[Discourse.UserAction.RESPONSE] = [
      Discourse.UserAction.RESPONSE,
      Discourse.UserAction.MENTION,
      Discourse.UserAction.QUOTE
    ]
    g
  )()

