/**
  This controller supports the interface for listing blocked email addresses in the admin section.

  @class AdminLogsBlockedEmailsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsBlockedEmailsController = Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  content: [],

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.BlockedEmail.findAll().then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  }
});
