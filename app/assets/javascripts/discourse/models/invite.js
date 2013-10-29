/**
  A data model representing an Invite

  @class Invite
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

Discourse.Invite = Discourse.Model.extend({

  rescind: function() {
    Discourse.ajax('/invites', {
      type: 'DELETE',
      data: { email: this.get('email') }
    });
    this.set('rescinded', true);
  }

});

Discourse.Invite.reopenClass({

  create: function() {
    var result = this._super.apply(this, arguments);
    if (result.user) {
      result.user = Discourse.User.create(result.user);
    }
    return result;
  }

});


