/**
  The modal for deleting a flag.

  @class AdminDeleteFlagController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

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

      return post.agreeFlags("delete").then(function () {
        adminFlagController.removeObject(post);
        self.send("closeModal");
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    }

  }

});
