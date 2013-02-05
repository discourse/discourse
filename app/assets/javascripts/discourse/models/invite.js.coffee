window.Discourse.Invite = Discourse.Model.extend

  rescind: ->
    $.ajax '/invites'
      type: 'DELETE'
      data: {email: @get('email')}

    @set('rescinded', true)


window.Discourse.Invite.reopenClass

  create: (invite) ->
    result = @_super(invite)
    result.user = Discourse.User.create(result.user) if result.user
    result

