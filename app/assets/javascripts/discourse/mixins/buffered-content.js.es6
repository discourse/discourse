import EmberObjectProxy from "@ember/object/proxy";

/* global BufferedProxy: true */
export function bufferedProperty(property) {
  const mixin = {
    buffered: Ember.computed(property, function() {
      return EmberObjectProxy.extend(BufferedProxy).create({
        content: this.get(property)
      });
    }),

    rollbackBuffer: function() {
      this.buffered.discardBufferedChanges();
    },

    commitBuffer: function() {
      this.buffered.applyBufferedChanges();
    }
  };

  // It's a good idea to null out fields when declaring objects
  mixin.property = null;

  return Ember.Mixin.create(mixin);
}

export default bufferedProperty("content");
