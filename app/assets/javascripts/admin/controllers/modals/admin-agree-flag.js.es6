import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  removeAfter: null,
  deleteSpammer: null,

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
