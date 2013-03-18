/**
  A data model representing an Invite

  @class Invite
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.Invite = Discourse.Model.extend({

  rescind: function() {
    $.ajax(Discourse.getURL('/invites'), {
      type: 'DELETE',
      data: { email: this.get('email') }
    });
    this.set('rescinded', true);
  }

});

Discourse.Invite.reopenClass({

  create: function(invite) {
    var result;
    result = this._super(invite);
    if (result.user) {
      result.user = Discourse.User.create(result.user);
    }
    return result;
  }

});


