export default class RawHtml {
  constructor(attrs) {
    this.html = attrs.html;
  }

  init() {
    return $(this.html)[0];
  }

  update(prev) {
    if (prev.html === this.html) { return; }
    return this.init();
  }

  destroy() { }
}

RawHtml.prototype.type = 'Widget';
