/**
  This controller supports the interface for dealing with flags in the admin section.

  @class AdminFlagsController
  @extends Ember.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminFlagsController = Ember.ArrayController.extend({

  /**
    Clear all flags on a post

    @method clearFlags
    @param {Discourse.FlaggedPost} item The post whose flags we want to clear
  **/
  disagreeFlags: function(item) {
    var adminFlagsController = this;
    item.disagreeFlags().then((function() {
      adminFlagsController.removeObject(item);
    }), function() {
      bootbox.alert(Em.String.i18n("admin.flags.error"));
    });
  },

  agreeFlags: function(item) {
    var adminFlagsController = this;
    item.agreeFlags().then((function() {
      adminFlagsController.removeObject(item);
    }), function() {
      bootbox.alert(Em.String.i18n("admin.flags.error"));
    });
  },

  deferFlags: function(item) {
    var adminFlagsController = this;
    item.deferFlags().then((function() {
      adminFlagsController.removeObject(item);
    }), function() {
      bootbox.alert(Em.String.i18n("admin.flags.error"));
    });
  },

  /**
    Deletes a post

    @method deletePost
    @param {Discourse.FlaggedPost} item The post to delete
  **/
  deletePost: function(item) {
    var adminFlagsController = this;
    item.deletePost().then((function() {
      adminFlagsController.removeObject(item);
    }), function() {
      bootbox.alert(Em.String.i18n("admin.flags.error"));
    });
  },

  /**
    Are we viewing the 'old' view?

    @property adminOldFlagsView
  **/
  adminOldFlagsView: Em.computed.equal('query', 'old'),

  /**
    Are we viewing the 'active' view?

    @property adminActiveFlagsView
  **/
  adminActiveFlagsView: Em.computed.equal('query', 'active')

});
