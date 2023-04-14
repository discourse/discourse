import BufferedProxy from "ember-buffered-proxy/proxy";
import Mixin from "@ember/object/mixin";
import { computed } from "@ember/object";

export function bufferedProperty(property) {
  const mixin = {
    buffered: computed(property, function () {
      return BufferedProxy.create({
        content: this.get(property),
      });
    }),

    rollbackBuffer() {
      this.buffered.discardBufferedChanges();
    },

    commitBuffer() {
      this.buffered.applyBufferedChanges();
    },
  };

  // It's a good idea to null out fields when declaring objects
  mixin.property = null;

  return Mixin.create(mixin);
}

export default bufferedProperty("content");
