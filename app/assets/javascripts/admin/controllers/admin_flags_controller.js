(function() {

  /**
    This controller supports the interface for dealing with flags in the admin section.

    @class AdminFlagsController    
    @extends Ember.Controller
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.AdminFlagsController = Ember.Controller.extend({
    
    clearFlags: function(item) {
      var _this = this;
      item.clearFlags().then((function() {
        _this.content.removeObject(item);
      }), (function() {
        bootbox.alert("something went wrong");
      }));
    },

    deletePost: function(item) {
      var _this = this;
      item.deletePost().then((function() {
        _this.content.removeObject(item);
      }), (function() {
        bootbox.alert("something went wrong");
      }));
    },

    adminOldFlagsView: (function() {
      return this.query === 'old';
    }).property('query'),

    adminActiveFlagsView: (function() {
      return this.query === 'active';
    }).property('query')
    
  });

}).call(this);
