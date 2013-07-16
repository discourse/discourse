/**
  A data model representing a list of Invites

  @class InviteList
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.InviteList = Discourse.Model.extend({
  empty: (function() {
    return this.blank('pending') && this.blank('redeemed');
  }).property('pending.@each', 'redeemed.@each')
});

Discourse.InviteList.reopenClass({

  findInvitedBy: function(user) {
    return Discourse.ajax("/users/" + (user.get('username_lower')) + "/invited.json").then(function (result) {
      var invitedList = result.invited_list;
      if (invitedList.pending) {
        invitedList.pending = invitedList.pending.map(function(i) {
          return Discourse.Invite.create(i);
        });
      }
      if (invitedList.redeemed) {
        invitedList.redeemed = invitedList.redeemed.map(function(i) {
          return Discourse.Invite.create(i);
        });
      }
      invitedList.user = user;
      return Discourse.InviteList.create(invitedList);
    });
  }

});


