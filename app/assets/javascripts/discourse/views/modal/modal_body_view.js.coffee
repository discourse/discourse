window.Discourse.ModalBodyView = window.Discourse.View.extend

  # Focus on first element
  didInsertElement: ->
    Em.run.next =>
      @.$('form input:first').focus()

  # Pass the errors to our errors view
  displayErrors: (errors, callback) ->
    @set('parentView.modalErrorsView.errors', errors)
    callback?()

  # Just use jQuery to show an alert. We don't need anythign fancier for now
  # like an actual ember view
  flash: (msg, flashClass="success") ->
    $alert = $('#modal-alert').hide().removeClass('alert-error', 'alert-success')
    $alert.addClass("alert alert-#{flashClass}").html(msg)
    $alert.fadeIn()
