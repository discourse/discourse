import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { reads } from "@ember/object/computed";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
  model: null,
  postNumber: null,
  postDate: null,
  filteredPostsCount: reads("topic.postStream.filteredPostsCount"),

  @action
  jump() {
    if (this.postNumber) {
      this._jumpToIndex(this.filteredPostsCount, this.postNumber);
    } else if (this.postDate) {
      this._jumpToDate(this.postDate);
    }
  },

  _jumpToIndex(postsCounts, postNumber) {
    const where = Math.min(postsCounts, Math.max(1, parseInt(postNumber, 10)));
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
  },
});
