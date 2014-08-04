/**
  The modal for agreeing with a flag.

  @class AdminAgreeFlagController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.ObjectController.extend(Discourse.ModalFunctionality, {

  needs: ["adminFlags"],

  actions: {

    agreeFlagHidePost: function () {
      var adminFlagController = this.get("controllers.adminFlags");
      var post = this.get("content");
      var self = this;

      return post.agreeFlags("hide").then(function () {
        adminFlagController.removeObject(post);
        self.send("closeModal");
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    agreeFlagKeepPost: function () {
      var adminFlagController = this.get("controllers.adminFlags");
      var post = this.get("content");
      var self = this;

      return post.agreeFlags("keep").then(function () {
        adminFlagController.removeObject(post);
        self.send("closeModal");
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    }

  }

});
