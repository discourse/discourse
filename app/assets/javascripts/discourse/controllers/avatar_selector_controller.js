/**
  The modal for selecting an avatar

  @class AvatarSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.AvatarSelectorController = Discourse.Controller.extend(Discourse.ModalFunctionality, {
  toggleUseUploadedAvatar: function(toggle) {
    this.set("use_uploaded_avatar", toggle);
  }
});
