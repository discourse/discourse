import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  model: null,
  postNumber: null,
  postDate: null,
  filteredPostsCount: Ember.computed.alias(
    "topic.postStream.filteredPostsCount"
  ),

  onShow() {
    Ember.run.next(() => $("#post-jump").focus());
  },

  actions: {
    jump() {
      if (this.get("postNumber")) {
        this._jumpToIndex(
          this.get("filteredPostsCount"),
          this.get("postNumber")
        );
      } else if (this.get("postDate")) {
        this._jumpToDate(this.get("postDate"));
      }
    }
  },

  _jumpToIndex(postsCounts, postNumber) {
    const where = Math.min(postsCounts, Math.max(1, parseInt(postNumber)));
    this.jumpToIndex(where);
    this._close();
  },

  _jumpToDate(date) {
    this.jumpToDate(date);
    this._close();
  },

  _close() {
    this.setProperties({ postNumber: null, postDate: null });
    this.send("closeModal");
  }
});
