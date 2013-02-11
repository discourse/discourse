#
# This class replaces a containerView of many buttons, which was responsible for 100ms
# of client rendering or so on a fast computer. It might be slightly uglier, but it's
# _much_ faster.
#
window.Discourse.PostMenuView = Ember.View.extend Discourse.Presence,
  tagName: 'section'
  classNames: ['post-menu-area', 'clearfix']

  # Delegate to render#{button}
  render: (buffer) ->
    post = @get('post')

    @renderReplies(post, buffer)
    buffer.push("<nav class='post-controls'>")
    Discourse.get('postButtons').forEach (button) => @["render#{button}"]?(post, buffer)
    buffer.push("</nav>")

  # Delegate click actions
  click: (e) ->
    $target = $(e.target)
    action = $target.data('action') || $target.parent().data('action')
    return unless action
    @["click#{action.capitalize()}"]?()

  # Trigger re rendering
  needsToRender: (->
    @rerender()
  ).observes('post.deleted_at', 'post.flagsAvailable.@each', 'post.url', 'post.bookmarked', 'post.reply_count', 'post.can_delete')

  # Replies Button
  renderReplies: (post, buffer) ->

    return if @get('post.replyFollowing')

    reply_count = post.get('reply_count')
    return if reply_count == 0

    buffer.push("<button class='show-replies' data-action='replies'>")
    buffer.push("<span class='badge-posts'>#{reply_count}</span>")

    buffer.push(Em.String.i18n("post.has_replies", count: reply_count))

    icon = if @get('postView.repliesShown') then 'icon-chevron-up' else 'icon-chevron-down'
    buffer.push("<i class='icon #{icon}'></i></button>")

  clickReplies: -> @get('postView').showReplies()

  # Delete button
  renderDelete: (post, buffer) ->

    if post.get('post_number') == 1 and @get('controller.content.can_delete')
      buffer.push("<button title=\"#{Em.String.i18n("topic.actions.delete")}\" data-action=\"deleteTopic\"><i class=\"icon-trash\"></i></button>")
      return

    # Show the correct button
    if post.get('deleted_at')
      if post.get('can_recover')
        buffer.push("<button title=\"#{Em.String.i18n("post.controls.undelete")}\" data-action=\"recover\"><i class=\"icon-undo\"></i></button>")
    else if post.get('can_delete')
      buffer.push("<button title=\"#{Em.String.i18n("post.controls.delete")}\" data-action=\"delete\"><i class=\"icon-trash\"></i></button>")

  clickDeleteTopic: -> @get('controller').deleteTopic()
  clickRecover: -> @get('controller').recoverPost(@get('post'))        
  clickDelete: -> @get('controller').deletePost(@get('post'))

  # Like button
  renderLike: (post, buffer) ->
    return unless post.get('actionByName.like.can_act')
    buffer.push("<button title=\"#{Em.String.i18n("post.controls.like")}\" data-action=\"like\" class='like'><i class=\"icon-heart\"></i></button>")

  clickLike: -> @get('post.actionByName.like')?.act()

  # Flag button
  renderFlag: (post, buffer) ->
    return unless @present('post.flagsAvailable')
    buffer.push("<button title=\"#{Em.String.i18n("post.controls.flag")}\" data-action=\"flag\"><i class=\"icon-flag\"></i></button>")

  clickFlag: -> @get('controller').showFlags(@get('post'))

  # Edit button
  renderEdit: (post, buffer) ->
    return unless post.get('can_edit')
    buffer.push("<button title=\"#{Em.String.i18n("post.controls.edit")}\" data-action=\"edit\"><i class=\"icon-pencil\"></i></button>")

  clickEdit: -> @get('controller').editPost(@get('post'))

  # Share button
  renderShare: (post, buffer) ->
    buffer.push("<button title=\"#{Em.String.i18n("post.controls.share")}\" data-share-url=\"#{post.get('url')}\"><i class=\"icon-link\"></i></button>")


  # Reply button
  renderReply: (post, buffer) ->
    return unless @get('controller.content.can_create_post')
    buffer.push("<button title=\"#{Em.String.i18n("post.controls.reply")}\" class='create' data-action=\"reply\"><i class='icon-reply'></i>#{Em.String.i18n("topic.reply.title")}</button>")

  clickReply: -> @get('controller').replyToPost(@get('post'))


  # Bookmark button
  renderBookmark: (post, buffer) ->
    return unless Discourse.get('currentUser')
    icon = 'bookmark'
    icon += '-empty' unless @get('post.bookmarked')
    buffer.push("<button title=\"#{Em.String.i18n("post.controls.bookmark")}\" data-action=\"bookmark\"><i class=\"icon-#{icon}\"></i></button>")

  clickBookmark: -> @get('post').toggleProperty('bookmarked')

