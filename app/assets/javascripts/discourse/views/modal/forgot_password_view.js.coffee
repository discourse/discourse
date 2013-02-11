window.Discourse.ForgotPasswordView = window.Discourse.ModalBodyView.extend Discourse.Presence,
  templateName: 'modal/forgot_password'
  title: Em.String.i18n('forgot_password.title')

  # You need a value in the field to submit it.
  submitDisabled: (-> @blank('accountEmailOrUsername')).property('accountEmailOrUsername')

  submit: ->
    $.post("/session/forgot_password", username: @get('accountEmailOrUsername'))
    # don't tell people what happened, this keeps it more secure (ensure same on server)
    @flash(Em.String.i18n('forgot_password.complete'))
    false
