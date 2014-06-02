/**
  This controller supports the interface for listing screened email addresses in the admin section.

  @class AdminLogsScreenedEmailsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsScreenedEmailsController = Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  content: [],

  clearBlock: function(row){
    row.clearBlock().then(function(){
      // feeling lazy
      window.location.reload();
    });
  },

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.ScreenedEmail.findAll().then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  }
});
