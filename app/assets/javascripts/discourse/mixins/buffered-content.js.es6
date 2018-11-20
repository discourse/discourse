/* global BufferedProxy: true */
export function bufferedProperty(property) {
  const mixin = {
    buffered: function() {
      return Em.ObjectProxy.extend(BufferedProxy).create({
        content: this.get(property)
      });
    }.property(property),

    rollbackBuffer: function() {
      this.get("buffered").discardBufferedChanges();
    },

    commitBuffer: function() {
      this.get("buffered").applyBufferedChanges();
    }
  };

  // It's a good idea to null out fields when declaring objects
  mixin.property = null;

  return Ember.Mixin.create(mixin);
}

export default bufferedProperty("content");
