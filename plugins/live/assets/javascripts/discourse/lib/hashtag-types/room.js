import HashtagTypeBase from "discourse/lib/hashtag-types/base";
import { iconHTML } from "discourse/lib/icon-library";

export default class RoomHashtagType extends HashtagTypeBase {
  get type() {
    return "room";
  }

  get preloadedData() {
    return [];
  }

  generateColorCssClasses() {
    return [];
  }

  generateIconHTML(hashtag) {
    return iconHTML(hashtag.icon || "microphone-lines");
  }
}
