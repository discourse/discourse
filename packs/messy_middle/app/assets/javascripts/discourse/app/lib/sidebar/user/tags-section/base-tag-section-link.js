export default class BaseTagSectionLink {
  constructor({ tagName }) {
    this.tagName = tagName;
  }

  get name() {
    return this.tagName;
  }

  get text() {
    return this.tagName;
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return "tag";
  }
}
