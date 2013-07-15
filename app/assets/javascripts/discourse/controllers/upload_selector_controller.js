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
  selectRemote: function() { this.set('localSelected', false); }

});
