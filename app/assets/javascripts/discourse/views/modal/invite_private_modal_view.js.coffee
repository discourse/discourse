window.Discourse.InvitePrivateModalView = window.Discourse.ModalBodyView.extend Discourse.Presence,
  templateName: 'modal/invite_private'
  title: Em.String.i18n('topic.invite_private.title')

  email: null
  error: false
  saving: false
  finished: false

  disabled: (->
    return true if @get('saving')
    @blank('emailOrUsername')
  ).property('emailOrUsername', 'saving')

  buttonTitle: (->
    return Em.String.i18n('topic.inviting') if @get('saving')
    return Em.String.i18n('topic.invite_private.action')
  ).property('saving')

  didInsertElement: ->
    Em.run.next => @.$('input').focus()

  invite: ->
    @set('saving', true)
    @set('error', false)

    # Invite the user to the private conversation    
    @get('topic').inviteUser(@get('emailOrUsername')).then =>
      # Success
      @set('saving', false)
      @set('finished', true)
    , =>
      # Failure
      @set('error', true)
      @set('saving', false)

    false