window.Discourse.ParentView = Discourse.EmbeddedPostView.extend

  # Nice animation for when the replies appear
  didInsertElement: ->
    @_super()

    $parentPost = @get('postView').$('section.parent-post')

    # Animate unless we're on a touch device
    if Discourse.get('touch')
      $parentPost.show()
    else
      $parentPost.slideDown()

