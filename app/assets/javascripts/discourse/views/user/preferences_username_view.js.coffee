window.Discourse.PreferencesUsernameView = Ember.View.extend
  templateName: 'user/username'
  classNames: ['user-preferences']


  didInsertElement: ->
    $('#change_username').focus()
