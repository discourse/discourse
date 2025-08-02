import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { bind } from "discourse/lib/decorators";

export default class ChatTrackMessage extends Modifier {
  didEnterViewport = null;
  didLeaveViewport = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [didEnterViewport, didLeaveViewport]) {
    this.didEnterViewport = didEnterViewport;
    this.didLeaveViewport = didLeaveViewport;

    this.intersectionObserver = new IntersectionObserver(
      this._intersectionObserverCallback,
      {
        root: document,
        threshold: 0,
      }
    );

    this.intersectionObserver.observe(element);
  }

  cleanup() {
    this.intersectionObserver?.disconnect();
  }

  @bind
  _intersectionObserverCallback(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        this.didEnterViewport?.();
      } else {
        this.didLeaveViewport?.();
      }
    });
  }
}
