import Modifier from "ember-modifier";
import { registerDestructor } from "@ember/destroyable";
import { bind } from "discourse-common/utils/decorators";

export default class ChatTrackMessage extends Modifier {
  visibleCallback = null;
  notVisibleCallback = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.cleanup());
  }

  modify(element, [callbacks = {}]) {
    this.visibleCallback = callbacks.visibleCallback;
    this.notVisibleCallback = callbacks.notVisibleCallback;

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
        this.visibleCallback?.();
      } else {
        this.notVisibleCallback?.();
      }
    });
  }
}
