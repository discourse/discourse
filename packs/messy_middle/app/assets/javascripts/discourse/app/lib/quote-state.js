export default class QuoteState {
  constructor() {
    this.clear();
  }

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
