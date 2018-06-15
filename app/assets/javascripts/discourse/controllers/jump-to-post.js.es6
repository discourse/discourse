import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  model: null,
  postNumber: null,

  onShow: () => {
    Ember.run.next(() => $("#post-jump").focus());
  },

  actions: {
    jump() {
      const max = this.get("topic.postStream.filteredPostsCount");
      const where = Math.min(
        max,
        Math.max(1, parseInt(this.get("postNumber")))
      );

      this.jumpToIndex(where);
      this.send("closeModal");
    }
  }
});
