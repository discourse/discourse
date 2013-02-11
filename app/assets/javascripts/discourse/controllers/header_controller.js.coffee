Discourse.HeaderController = Ember.Controller.extend Discourse.Presence,
  topic: null
  showExtraInfo: false

  toggleStar: ->
    @get('topic')?.toggleStar()
    false
