/**
  The modal for selecting an avatar

  @class AvatarSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.AvatarSelectorController = Discourse.Controller.extend(Discourse.ModalFunctionality, {

  actions: {
    useUploadedAvatar: function() { this.set("use_uploaded_avatar", true); },
    useGravatar: function() { this.set("use_uploaded_avatar", false); }
  },

  avatarTemplate: function() {
    return this.get("use_uploaded_avatar") ? this.get("uploaded_avatar_template") : this.get("gravatar_template");
  }.property("use_uploaded_avatar", "uploaded_avatar_template", "gravatar_template")

});
