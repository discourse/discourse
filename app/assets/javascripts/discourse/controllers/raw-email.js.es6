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

  loadEmail: function(postId) {
    var self = this;
    Discourse.Post.load(postId).then(function (result) {
      self.set("raw_email", result.get('raw_email'));
    });
  }

});
