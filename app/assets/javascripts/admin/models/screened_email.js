/**
  Represents an email address that is watched for during account registration,
  and an action is taken.

  @class ScreenedEmail
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ScreenedEmail = Discourse.Model.extend({
  actionName: function() {
    return I18n.t("admin.logs.screened_actions." + this.get('action'));
  }.property('action')
});

Discourse.ScreenedEmail.reopenClass({
  findAll: function(filter) {
    return Discourse.ajax("/admin/logs/screened_emails.json").then(function(screened_emails) {
      return screened_emails.map(function(b) {
        return Discourse.ScreenedEmail.create(b);
      });
    });
  }
});
