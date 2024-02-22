import Component from "@ember/component";
import { next } from "@ember/runloop";
import $ from "jquery";
import Scrolling from "discourse/mixins/scrolling";

export default Component.extend(Scrolling, {
  didReceiveAttrs() {
    this._super(...arguments);

    this.set("trackerName", `scroll-tracker-${this.name}`);
  },

  didInsertElement() {
    this._super(...arguments);

    this.bindScrolling();
  },

  didRender() {
    this._super(...arguments);

    const data = this.session.get(this.trackerName);
    if (data && data.position >= 0 && data.tag === this.tag) {
      next(() => $(window).scrollTop(data.position + 1));
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    this.unbindScrolling();
  },

  scrolled() {
    this._super(...arguments);

    this.session.set(this.trackerName, {
      position: $(window).scrollTop(),
      tag: this.tag,
    });
  },
});
