/**
  This controller supports the interface for listing screened IP addresses in the admin section.

  @class AdminLogsScreenedIpAddressesController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsScreenedIpAddressesController = Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  content: [],

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.ScreenedIpAddress.findAll().then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  }
});
