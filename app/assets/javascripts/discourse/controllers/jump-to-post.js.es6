import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  model: null,
  postNumber: null,

  actions: {
    jump() {
      let where = parseInt(this.get('postNumber'));
      if (where < 1) { where = 1; }
      const max = this.get('topic.postStream.filteredPostsCount');
      if (where > max) { where = max; }

      this.jumpToIndex(where);
      this.send('closeModal');
    }
  }
});
