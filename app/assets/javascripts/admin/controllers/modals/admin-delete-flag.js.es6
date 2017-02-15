import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  adminFlagsList: Ember.inject.controller(),

  actions: {
    deletePostDeferFlag() {
      const adminFlagController = this.get("adminFlagsList");
      const post = this.get("content");

      return post.deferFlags(true).then(() => {
        adminFlagController.get('model').removeObject(post);
        this.send("closeModal");
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    },

    deletePostAgreeFlag() {
      const adminFlagController = this.get("adminFlagsList");
      const post = this.get("content");

      return post.agreeFlags("delete").then(() => {
        adminFlagController.get('model').removeObject(post);
        this.send("closeModal");
      }, function () {
        bootbox.alert(I18n.t("admin.flags.error"));
      });
    }
  }
});
