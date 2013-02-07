window.Discourse.PreferencesEmailView = Ember.View.extend
  templateName: 'user/email'
  classNames: ['user-preferences']

  didInsertElement: ->
    $('#change_email').focus()
