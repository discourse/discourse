import { setOwner } from "@ember/application";
import { debounce } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { getHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";

export default class HashtagTypeBase {
  static loadingIds = {};

  constructor(owner) {
    setOwner(this, owner);
    this.registeredIds = new Set();
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

  registerCss(model) {
    this.registeredIds.add(model.id);
    document.querySelector("#hashtag-css-generator").innerHTML +=
      "\n" + this.generateColorCssClasses(model).join("\n");
  }

  generateIconHTML() {
    throw "not implemented";
  }

  async _load() {
    const data = Object.fromEntries(
      Object.entries(this.loadingIds).map(([hashtagType, ids]) => [
        hashtagType,
        [...ids],
      ])
    );
    this.loadingIds = {};

    const hashtags = await ajax("/hashtags/by-ids", { data });
    const hashtagClasses = getHashtagTypeClasses();
    Object.keys(hashtagClasses).forEach((hashtagType) =>
      hashtags[hashtagType]?.forEach((hashtag) =>
        hashtagClasses[hashtagType].registerCss(hashtag)
      )
    );
  }

  load(id) {
    if (this.registeredIds.has(parseInt(id, 10))) {
      return;
    }

    (this.loadingIds[this.type] ||= new Set()).add(id);
    debounce(this, this._load, 100, false);
  }
}
