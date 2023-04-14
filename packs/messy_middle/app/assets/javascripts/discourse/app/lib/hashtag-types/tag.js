import HashtagTypeBase from "./base";

export default class TagHashtagType extends HashtagTypeBase {
  get type() {
    return "tag";
  }

  get preloadedData() {
    return [];
  }

  generateColorCssClasses() {
    return [];
  }
}
