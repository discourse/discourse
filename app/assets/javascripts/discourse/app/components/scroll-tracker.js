import Component from "@ember/component";
import { next } from "@ember/runloop";
import $ from "jquery";
import Scrolling from "discourse/mixins/scrolling";

export default class ScrollTracker extends Component.extend(Scrolling) {
  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    this.set("trackerName", `scroll-tracker-${this.name}`);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    this.bindScrolling();
  }

  didRender() {
    super.didRender(...arguments);

    const data = this.session.get(this.trackerName);
    if (data && data.position >= 0 && data.tag === this.tag) {
      next(() => $(window).scrollTop(data.position + 1));
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.unbindScrolling();
  }

  scrolled() {
    this.session.set(this.trackerName, {
      position: $(window).scrollTop(),
      tag: this.tag,
    });
  }
}
