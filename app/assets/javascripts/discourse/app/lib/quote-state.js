export default class QuoteState {
  constructor() {
    this.clear();
  }

  selected(data, buffer, opts) {
    this.data = data;
    this.buffer = buffer;
    this.opts = opts;
  }

  clear() {
    this.buffer = "";
    this.data = null;
    this.opts = null;
  }
}
