export default class RangeRef {
  constructor(selector) {
    this.selector = selector;
    this.#updateRect();
    this.setupListeners(selector);
  }

  #updateRect() {
    const selection = document.getSelection();
    this.range = selection && selection.rangeCount && selection.getRangeAt(0);
    this.rect = this.range.getBoundingClientRect();
    return this.rect;
  }

  getBoundingClientRect() {
    return this.rect;
  }

  setupListeners(selector) {
    const update = () => this.#updateRect();
    document.querySelector(selector).addEventListener("mouseup", update);
    window.addEventListener("scroll", update);
    document.scrollingElement.addEventListener("scroll", update);
  }

  clearListeners() {
    const update = () => this.#updateRect();
    document
      .querySelectorAll(this.selector)
      .forEach((element) => element.removeEventListener("mouseup", update));
    window.removeEventListener("scroll", update);
    document.scrollingElement.removeEventListener("scroll", update);
  }

  get clientWidth() {
    return this.rect.width;
  }

  get clientHeight() {
    return this.rect.height;
  }
}
