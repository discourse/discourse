import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  adminFlagsList: Ember.inject.controller(),

  _agreeFlag: function (actionOnPost) {
    const adminFlagController = this.get("adminFlagsList");
    const post = this.get("content");

    return post.agreeFlags(actionOnPost).then(() => {
      adminFlagController.get('model').removeObject(post);
      this.send("closeModal");
    }, function () {
      bootbox.alert(I18n.t("admin.flags.error"));
    });
  },

  actions: {
    agreeFlagHidePost: function () { return this._agreeFlag("hide"); },
    agreeFlagKeepPost: function () { return this._agreeFlag("keep"); },
    agreeFlagRestorePost: function () { return this._agreeFlag("restore"); }
  }

});
