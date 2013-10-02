/**
  This controller supports the interface for dealing with flags in the admin section.

  @class AdminFlagsController
  @extends Ember.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminFlagsController = Ember.ArrayController.extend({

  actions: {
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
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    agreeFlags: function(item) {
      var adminFlagsController = this;
      item.agreeFlags().then((function() {
        adminFlagsController.removeObject(item);
      }), function() {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    deferFlags: function(item) {
      var adminFlagsController = this;
      item.deferFlags().then((function() {
        adminFlagsController.removeObject(item);
      }), function() {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    /**
      Deletes a post

      @method deletePost
      @param {Discourse.FlaggedPost} post The post to delete
    **/
    deletePost: function(post) {
      var adminFlagsController = this;
      post.deletePost().then((function() {
        adminFlagsController.removeObject(post);
      }), function() {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    /**
      Deletes a user and all posts and topics created by that user.

      @method deleteSpammer
      @param {Discourse.FlaggedPost} item The post to delete
    **/
    deleteSpammer: function(item) {
      item.get('user').deleteAsSpammer(function() { window.location.reload(); });
    }
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
  adminActiveFlagsView: Em.computed.equal('query', 'active'),

  loadMore: function(){
    var flags = this.get('model');
    return Discourse.FlaggedPost.findAll(this.get('query'),flags.length+1).then(function(data){
      if(data.length===0){
        flags.set('allLoaded',true);
      }
      flags.addObjects(data);
    });
  }

});
