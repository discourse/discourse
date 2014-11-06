import ModalFunctionality from 'discourse/mixins/modal-functionality';

import ObjectController from 'discourse/controllers/object';

/**
  This controller handles displaying of raw email

  @class RawEmailController
  @extends ObjectController
  @namespace Discourse
  @uses ModalFunctionality
  @module Discourse
**/
export default ObjectController.extend(ModalFunctionality, {
  rawEmail: "",

  loadRawEmail: function(postId) {
    var self = this;
    Discourse.Post.loadRawEmail(postId).then(function (result) {
      self.set("rawEmail", result);
    });
  }

});
