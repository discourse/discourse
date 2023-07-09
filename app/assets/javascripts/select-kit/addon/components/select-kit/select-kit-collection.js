import Component from "@ember/component";
import { action, computed } from "@ember/object";

const STEP = 20;

export default Component.extend({
  tagName: "",

  limit: 0,

  didReceiveAttrs() {
    this._super(...arguments);

    this.set("limit", STEP);
  },

  @computed("limit", "collection.content.[]")
  get renderedContent() {
    return this.collection.content.slice(0, this.limit);
  },

  @action
  bottomReached() {
    this.set("limit", this.limit + STEP);
  },
});
