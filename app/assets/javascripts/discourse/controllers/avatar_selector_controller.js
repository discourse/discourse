/**
  The modal for selecting an avatar

  @class AvatarSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.AvatarSelectorController = Discourse.Controller.extend(Discourse.ModalFunctionality, {
  init: function() {
    // copy some data to support the cancel action
    this.setProperties(this.get("currentUser").getProperties(
      "username",
      "has_uploaded_avatar",
      "use_uploaded_avatar",
      "gravatar_template",
      "uploaded_avatar_template"
    ));
  },

  toggleUseUploadedAvatar: function(toggle) {
    this.set("use_uploaded_avatar", toggle);
  },

  saveAvatarSelection: function() {
    // sends the information to the server if it has changed
    if (this.get("use_uploaded_avatar") !== this.get("currentUser.use_uploaded_avatar")) {
      var data = { use_uploaded_avatar: this.get("use_uploaded_avatar") };
      Discourse.ajax("/users/" + this.get("currentUser.username") + "/preferences/avatar/toggle", { type: 'PUT', data: data });
    }
    // saves the data back to the currentUser object
    var currentUser = this.get("currentUser");
    currentUser.setProperties(this.getProperties(
      "has_uploaded_avatar",
      "use_uploaded_avatar",
      "gravatar_template",
      "uploaded_avatar_template"
    ));
    if (this.get("use_uploaded_avatar")) {
      currentUser.set("avatar_template", this.get("uploaded_avatar_template"));
    } else {
      currentUser.set("avatar_template", this.get("gravatar_template"));
    }
  }
});
