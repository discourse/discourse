(function() {

  /**
    This controller supports the interface for dealing with flags in the admin section.

    @class AdminFlagsController    
    @extends Ember.Controller
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.AdminFlagsController = Ember.Controller.extend({
    
    /**
      Clear all flags on a post

      @method clearFlags
      @param {Discourse.FlaggedPost} item The post whose flags we want to clear
    **/
    clearFlags: function(item) {
      var _this = this;
      item.clearFlags().then((function() {
        _this.content.removeObject(item);
      }), (function() {
        bootbox.alert("something went wrong");
      }));
    },

    /**
      Deletes a post

      @method deletePost
      @param {Discourse.FlaggedPost} item The post to delete
    **/
    deletePost: function(item) {
      var _this = this;
      item.deletePost().then((function() {
        _this.content.removeObject(item);
      }), (function() {
        bootbox.alert("something went wrong");
      }));
    },

    /**
      Are we viewing the 'old' view?

      @property adminOldFlagsView
    **/
    adminOldFlagsView: (function() {
      return this.query === 'old';
    }).property('query'),

    /**
      Are we viewing the 'active' view?

      @property adminActiveFlagsView
    **/
    adminActiveFlagsView: (function() {
      return this.query === 'active';
    }).property('query')
    
  });

}).call(this);
