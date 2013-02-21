(function() {

  /**
    This controller supports the default interface when you enter the admin section.

    @class AdminDashboardController
    @extends Ember.Controller
    @namespace Discourse
    @module Discourse
  **/
  window.Discourse.AdminDashboardController = Ember.Controller.extend({
    loading: true,
    versionCheck: null
  });

}).call(this);
