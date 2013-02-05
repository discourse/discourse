window.Discourse.InviteModalView = window.Discourse.ModalBodyView.extend Discourse.Presence,
  templateName: 'modal/invite'
  title: Em.String.i18n('topic.invite_reply.title')

  email: null
  error: false
  saving: false
  finished: false

  disabled: (->
    return true if @get('saving')
    return true if @blank('email')
    return true unless Discourse.Utilities.emailValid(@get('email'))
    false
  ).property('email', 'saving')

  buttonTitle: (->
    return Em.String.i18n('topic.inviting') if @get('saving')
    return Em.String.i18n('topic.invite_reply.title')
  ).property('saving')

  successMessage: (->
    Em.String.i18n('topic.invite_reply.success', email: @get('email'))
  ).property('email')

  didInsertElement: ->
    Em.run.next => @.$('input').focus()

  createInvite: ->
    @set('saving', true)
    @set('error', false)
    
    @get('topic').inviteUser(@get('email')).then =>
      # Success
      @set('saving', false)
      @set('finished', true)
    , =>
      # Failure
      @set('error', true)
      @set('saving', false)

    false
