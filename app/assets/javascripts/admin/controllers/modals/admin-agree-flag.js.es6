import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  removeAfter: null,

  _agreeFlag(action) {
    let flaggedPost = this.get('model');
    return this.removeAfter(flaggedPost.agreeFlags(action)).then(() => {
      this.send('closeModal');
    });
  },

  actions: {
    agreeFlagHidePost() { return this._agreeFlag("hide"); },
    agreeFlagKeepPost() { return this._agreeFlag("keep"); },
    agreeFlagRestorePost() { return this._agreeFlag("restore"); }
  }

});
