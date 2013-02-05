window.Discourse.ExcerptPostView = Ember.View.extend
  mute: ->
    @update(true)

  unmute: ->
    @update(false)

  refreshLater: Discourse.debounce((->
    @get('controller.controllers.listController').refresh()
  ), 1000)


  update: (v)->
    @set('muted',v)
    $.post "/t/#{@topic_id}/#{if v then "mute" else "unmute"}",
      _method: 'put'
      success: =>
        # I experimented with this, but if feels like whackamole
        # @refreshLater()
