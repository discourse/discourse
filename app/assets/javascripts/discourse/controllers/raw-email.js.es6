import ModalFunctionality from 'discourse/mixins/modal-functionality';
import Post from 'discourse/models/post';
import IncomingEmail from 'admin/models/incoming-email';

// This controller handles displaying of raw email
export default Ember.Controller.extend(ModalFunctionality, {
  rawEmail: "",

  loadRawEmail(postId) {
    return Post.loadRawEmail(postId)
               .then(result => this.set("rawEmail", result.raw_email));
  },

  loadIncomingRawEmail(incomingEmailId) {
    return IncomingEmail.loadRawEmail(incomingEmailId)
                        .then(result => this.set("rawEmail", result.raw_email));
  }

});
