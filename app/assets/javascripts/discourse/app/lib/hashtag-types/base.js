import { setOwner } from "@ember/application";

export default class HashtagTypeBase {
  constructor(container) {
    setOwner(this, container);
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

  generateIconHTML() {
    throw "not implemented";
  }
}
