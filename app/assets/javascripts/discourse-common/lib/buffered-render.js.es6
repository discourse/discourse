import { scheduleOnce } from "@ember/runloop";
// Ember 2.0 removes buffered rendering, but we can still implement it ourselves.
// In the long term we'll want to remove this.

const Mixin = {
  _customRender() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    const buffer = [];
    this.buildBuffer(buffer);
    this.element.innerHTML = buffer.join("");
  },

  rerenderBuffer() {
    scheduleOnce("render", this, this._customRender);
  }
};

export function bufferedRender(obj) {
  if (!obj.buildBuffer) {
    Ember.warn("Missing `buildBuffer` method", {
      id: "discourse.buffered-render.missing-build-buffer"
    });
    return obj;
  }

  const caller = {};

  caller.didRender = function() {
    this._super(...arguments);
    this._customRender();
  };

  const triggers = obj.rerenderTriggers;
  if (triggers) {
    caller.init = function() {
      this._super(...arguments);
      triggers.forEach(k => this.addObserver(k, this.rerenderBuffer));
    };
  }
  delete obj.rerenderTriggers;

  return Ember.Mixin.create(Mixin, caller, obj);
}
