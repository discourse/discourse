export default class QuoteState {
  constructor() {
    this.clear();
  }

  selected(postId, buffer) {
    this.postId = postId;
    this.buffer = buffer;
  }

  clear() {
    this.buffer = "";
    this.postId = null;
  }
}
