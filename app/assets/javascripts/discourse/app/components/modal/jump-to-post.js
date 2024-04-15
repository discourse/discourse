import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class JumpToPost extends Component {
  @tracked postNumber;
  @tracked postDate;

  get filteredPostsCount() {
    return this.args.model.topic.postStream.filteredPostsCount;
  }

  _jumpToIndex(postsCounts, postNumber) {
    const where = Math.min(postsCounts, Math.max(1, parseInt(postNumber, 10)));
    this.args.model.jumpToIndex(where);
    this.args.closeModal();
  }

  _jumpToDate(date) {
    this.args.model.jumpToDate(date);
    this.args.closeModal();
  }

  @action
  jump() {
    if (this.postNumber) {
      this._jumpToIndex(this.filteredPostsCount, this.postNumber);
    } else if (this.postDate) {
      this._jumpToDate(this.postDate);
    }
  }
}
