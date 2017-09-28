import ModalFunctionality from 'discourse/mixins/modal-functionality';
import DeleteSpammerModal from 'admin/mixins/delete-spammer-modal';

export default Ember.Controller.extend(ModalFunctionality, DeleteSpammerModal, {
  removeAfter: null,

  actions: {
    deletePostDeferFlag() {
      let flaggedPost = this.get('model');
      this.removeAfter(flaggedPost.deferFlags(true)).then(() => {
        this.send('closeModal');
      });
    },

    deletePostAgreeFlag() {
      let flaggedPost = this.get('model');
      this.removeAfter(flaggedPost.agreeFlags('delete')).then(() => {
        this.send('closeModal');
      });
    }
  }
});
