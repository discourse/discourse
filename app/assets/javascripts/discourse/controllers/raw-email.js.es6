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
  raw_email: "",

  loadRawEmail: function(postId) {
    var self = this;
    Discourse.Post.loadRawEmail(postId).then(function (raw_email) {
      self.set("raw_email", raw_email);
    });
  }

});
