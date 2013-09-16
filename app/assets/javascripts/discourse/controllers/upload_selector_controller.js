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

  actions: {
    selectLocal: function() { this.set('localSelected', true); },
    selectRemote: function() { this.set('localSelected', false); }
  },

  localTitle: function() { return Discourse.UploadSelectorController.translate("local_title"); }.property(),
  remoteTitle: function() { return Discourse.UploadSelectorController.translate("remote_title"); }.property(),
  uploadTitle: function() { return Discourse.UploadSelectorController.translate("upload_title"); }.property(),
  addTitle: function() { return Discourse.UploadSelectorController.translate("add_title"); }.property(),

  localTip: function() {
    var opts = { authorized_extensions: Discourse.Utilities.authorizedExtensions() };
    return Discourse.UploadSelectorController.translate("local_tip", opts);
  }.property(),

  remoteTip: function() {
    var opts = { authorized_extensions: Discourse.Utilities.authorizedExtensions() };
    return Discourse.UploadSelectorController.translate("remote_tip", opts);
  }.property(),

  addUploadIcon: function() { return Discourse.Utilities.allowsAttachments() ? "icon-file-alt" : "icon-picture"; }.property()

});

Discourse.UploadSelectorController.reopenClass({
  translate: function(key, options) {
    var opts = options || {};
    if (Discourse.Utilities.allowsAttachments()) { key += "_with_attachments"; }
    return I18n.t("upload_selector." + key, opts);
  }
});
