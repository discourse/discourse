/**
  This controller supports the interface for listing screened IP addresses in the admin section.

  @class AdminLogsScreenedIpAddressesController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
export default Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  content: [],
  itemController: 'admin-log-screened-ip-address',

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.ScreenedIpAddress.findAll().then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  },

  actions: {
    recordAdded: function(arg) {
      this.get("content").unshiftObject(arg);
    }
  }
});
