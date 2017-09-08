import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
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
