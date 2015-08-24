const Invite = Discourse.Model.extend({

  rescind() {
    Discourse.ajax('/invites', {
      type: 'DELETE',
      data: { email: this.get('email') }
    });
    this.set('rescinded', true);
  },

  reinvite() {
    Discourse.ajax('/invites/reinvite', {
      type: 'POST',
      data: { email: this.get('email') }
    });
    this.set('reinvited', true);
  }

});

Invite.reopenClass({

  create() {
    var result = this._super.apply(this, arguments);
    if (result.user) {
      result.user = Discourse.User.create(result.user);
    }
    return result;
  },

  findInvitedBy(user, filter, search, offset) {
    if (!user) { return Em.RSVP.resolve(); }

    var data = {};
    if (!Em.isNone(filter)) { data.filter = filter; }
    if (!Em.isNone(search)) { data.search = search; }
    data.offset = offset || 0;

    return Discourse.ajax("/users/" + user.get('username_lower') + "/invited.json", {data}).then(function (result) {
      result.invites = result.invites.map(function (i) {
        return Invite.create(i);
      });

      return Em.Object.create(result);
    });
  },

  findInvitedCount(user) {
    if (!user) { return Em.RSVP.resolve(); }
    return Discourse.ajax("/users/" + user.get('username_lower') + "/invited_count.json").then(result => Em.Object.create(result.counts));
  }

});

export default Invite;
