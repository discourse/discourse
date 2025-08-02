import { tracked } from "@glimmer/tracking";

export default class QuoteState {
  @tracked postId = null;
  @tracked buffer = "";
  @tracked opts = null;

  selected(postId, buffer, opts) {
    this.postId = postId;
    this.buffer = buffer;
    this.opts = opts;
  }

  clear() {
    this.buffer = "";
    this.postId = null;
    this.opts = null;
  }
}
