/**
  This controller supports the interface for listing screened URLs in the admin section.

  @class AdminLogsScreenedUrlsController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsScreenedUrlsController = Ember.ArrayController.extend(Discourse.Presence, {
  loading: false,
  content: [],

  show: function() {
    var self = this;
    this.set('loading', true);
    Discourse.ScreenedUrl.findAll().then(function(result) {
      self.set('content', result);
      self.set('loading', false);
    });
  }
});
