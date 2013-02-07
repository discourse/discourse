window.Discourse.PrependPostView = Em.ContainerView.extend

  init: ->
    @_super()
    @trigger('prependPostContent')


