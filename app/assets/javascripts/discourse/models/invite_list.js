(function() {

  window.Discourse.InviteList = Discourse.Model.extend(Discourse.Presence, {
    empty: (function() {
      return this.blank('pending') && this.blank('redeemed');
    }).property('pending.@each', 'redeemed.@each')
  });

  window.Discourse.InviteList.reopenClass({
    findInvitedBy: function(user) {
      var promise;
      promise = new RSVP.Promise();
      jQuery.ajax({
        url: "/users/" + (user.get('username_lower')) + "/invited.json",
        success: function(result) {
          var invitedList;
          invitedList = result.invited_list;
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
          return promise.resolve(Discourse.InviteList.create(invitedList));
        }
      });
      return promise;
    }
  });

}).call(this);
