import ModalFunctionality from 'discourse/mixins/modal-functionality';
import DeleteSpammerModal from 'admin/mixins/delete-spammer-modal';

export default Ember.Controller.extend(ModalFunctionality, DeleteSpammerModal, {
  removeAfter: null,

  actions: {
    agreeDeleteSpammer(user) {
      return this.removeAfter(user.deleteAsSpammer()).then(() => {
        this.send('closeModal');
      });
    },

    perform(action) {
      let flaggedPost = this.get('model');
      return this.removeAfter(flaggedPost.agreeFlags(action)).then(() => {
        this.send('closeModal');
      });
    },
  }
});
