window.Discourse.InviteList = Discourse.Model.extend Discourse.Presence,

  empty: (->
    return @blank('pending') and @blank('redeemed')
  ).property('pending.@each', 'redeemed.@each')

window.Discourse.InviteList.reopenClass

  findInvitedBy: (user) ->
    promise = new RSVP.Promise()
    $.ajax
      url: "/users/#{user.get('username_lower')}/invited.json"
      success: (result) ->
        invitedList = result.invited_list
        invitedList.pending = (invitedList.pending.map (i) -> Discourse.Invite.create(i)) if invitedList.pending
        invitedList.redeemed = (invitedList.redeemed.map (i) -> Discourse.Invite.create(i)) if invitedList.redeemed
        invitedList.user = user
        promise.resolve(Discourse.InviteList.create(invitedList))
    promise
