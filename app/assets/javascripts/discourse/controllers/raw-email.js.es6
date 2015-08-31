import ModalFunctionality from 'discourse/mixins/modal-functionality';

// This controller handles displaying of raw email
export default Ember.Controller.extend(ModalFunctionality, {
  rawEmail: "",

  loadRawEmail: function(postId) {
    var self = this;
    Discourse.Post.loadRawEmail(postId).then(function (result) {
      self.set("rawEmail", result);
    });
  }

});
