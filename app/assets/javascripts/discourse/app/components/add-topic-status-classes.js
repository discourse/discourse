import Component from "@ember/component";
import { scheduleOnce } from "@ember/runloop";

export default Component.extend({
  tagName: "",

  didInsertElement() {
    this._super(...arguments);
    this.refreshClass();
  },

  _updateClass() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    const body = document.getElementsByTagName("body")[0];

    this._removeClass();

    if (this.topic.invisible) {
      body.classList.add("topic-status-unlisted");
    }
    if (this.topic.pinned) {
      body.classList.add("topic-status-pinned");
    }
    if (this.topic.unpinned) {
      body.classList.add("topic-status-unpinned");
    }
  },

  didReceiveAttrs() {
    this._super(...arguments);
    this.refreshClass();
  },

  refreshClass() {
    scheduleOnce("afterRender", this, this._updateClass);
  },

  _removeClass() {
    const regx = new RegExp(/\btopic-status-\S+/, "g");
    const body = document.getElementsByTagName("body")[0];
    body.className = body.className.replace(regx, "");
  },

  willDestroyElement() {
    this._super(...arguments);
    this._removeClass();
  },
});
