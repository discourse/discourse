/**
  The modal for inviting a user to a topic

  @class ImageSelectorController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.ImageSelectorController = Discourse.Controller.extend(Discourse.ModalFunctionality, {

  selectLocal: function() {
    this.set('localSelected', true);
  },

  selectRemote: function() {
    this.set('localSelected', false);
  },

  remoteSelected: Em.computed.not('localSelected')

});