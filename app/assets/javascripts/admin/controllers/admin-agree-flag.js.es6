import ModalFunctionality from 'discourse/mixins/modal-functionality';

import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend(ModalFunctionality, {

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
