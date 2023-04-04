export default class HashtagTypeBase {
  constructor(container) {
    this.container = container;
  }

  get type() {
    throw "not implemented";
  }

  get preloadedData() {
    throw "not implemented";
  }

  generateColorCssClasses() {
    throw "not implemented";
  }
}
