/**
  The modal for upload a file to a post

  @class UploadSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.UploadSelectorController = Discourse.Controller.extend(Discourse.ModalFunctionality, {
  localSelected: true,
  remoteSelected: Em.computed.not('localSelected'),

  selectLocal: function() { this.set('localSelected', true); },
  selectRemote: function() { this.set('localSelected', false); },

  localTitle: function() { return Discourse.UploadSelectorController.translate("local_title") }.property(),
  remoteTitle: function() { return Discourse.UploadSelectorController.translate("remote_title") }.property(),
  localTip: function() { return Discourse.UploadSelectorController.translate("local_tip") }.property(),
  remoteTip: function() { return Discourse.UploadSelectorController.translate("remote_tip") }.property(),
  uploadTitle: function() { return Discourse.UploadSelectorController.translate("upload_title") }.property(),
  addTitle: function() { return Discourse.UploadSelectorController.translate("add_title") }.property()

});

Discourse.UploadSelectorController.reopenClass({
  translate: function(key) {
    if (Discourse.Utilities.allowsAttachments()) key += "_with_attachments";
    return I18n.t("upload_selector." + key);
  }
});
