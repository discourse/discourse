/**
  The modal for selecting an avatar

  @class AvatarSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.Controller.extend(Discourse.ModalFunctionality, {

  actions: {
    useUploadedAvatar: function() {
      this.set("selected", "uploaded");
    },
    useGravatar: function() {
      this.set("selected", "gravatar");
    },
    useSystem: function() {
      this.set("selected", "system");
    }
  }
});
