/**
  The modal for upload a file to a post

  @class UploadSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.UploadSelectorController = Discourse.Controller.extend(Discourse.ModalFunctionality, {
  local: true,
  remote: Em.computed.not("local"),

  actions: {
    useLocal: function() { this.set("local", true); },
    useRemote: function() { this.set("local", false); }
  }

});

Discourse.UploadSelectorController.reopenClass({
  translate: function(key, options) {
    var opts = options || {};
    if (Discourse.Utilities.allowsAttachments()) { key += "_with_attachments"; }
    return I18n.t("upload_selector." + key, opts);
  }
});
