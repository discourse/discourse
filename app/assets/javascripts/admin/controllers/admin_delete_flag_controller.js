/**
  The modal for deleting a flag.

  @class AdminDeleteFlagController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.AdminDeleteFlagController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  needs: ["adminFlags"],

  actions: {

    deletePostDeferFlag: function () {
      var adminFlagController = this.get("controllers.adminFlags");
      var post = this.get("content");
      var self = this;

      return post.deferFlags(true).then(function () {
        adminFlagController.removeObject(post);
        self.send("closeModal");
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    deletePostAgreeFlag: function () {
      var adminFlagController = this.get("controllers.adminFlags");
      var post = this.get("content");
      var self = this;

      return post.agreeFlags(true).then(function () {
        adminFlagController.removeObject(post);
        self.send("closeModal");
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    /**
      Deletes a user and all posts and topics created by that user.

      @method deleteSpammer
    **/
    deleteSpammer: function () {
      this.get("content.user").deleteAsSpammer(function() { window.location.reload(); });
    }
  }

});
