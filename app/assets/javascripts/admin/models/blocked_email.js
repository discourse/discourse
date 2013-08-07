/**
  Represents an email address that is watched for during account registration,
  and an action is taken.

  @class BlockedEmail
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.BlockedEmail = Discourse.Model.extend({
  actionName: function() {
    return I18n.t("admin.logs.blocked_emails.actions." + this.get('action'));
  }.property('action')
});

Discourse.BlockedEmail.reopenClass({
  findAll: function(filter) {
    return Discourse.ajax("/admin/logs/blocked_emails.json").then(function(blocked_emails) {
      return blocked_emails.map(function(b) {
        return Discourse.BlockedEmail.create(b);
      });
    });
  }
});
