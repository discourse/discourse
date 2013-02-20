(function() {

  window.Discourse.Invite = Discourse.Model.extend({
    rescind: function() {
      jQuery.ajax('/invites', {
        type: 'DELETE',
        data: {
          email: this.get('email')
        }
      });
      return this.set('rescinded', true);
    }
  });

  window.Discourse.Invite.reopenClass({
    create: function(invite) {
      var result;
      result = this._super(invite);
      if (result.user) {
        result.user = Discourse.User.create(result.user);
      }
      return result;
    }
  });

}).call(this);
