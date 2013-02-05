window.Discourse.View = Ember.View.extend Discourse.Presence,

  # Overwrite this to do a different display
  displayErrors: (errors, callback) ->
    alert(errors.join("\n"))
    callback?()
