/* global BufferedProxy: true */
export function bufferedProperty(property) {
  return Ember.Mixin.create({
    buffered: function() {
      return Em.ObjectProxy.extend(BufferedProxy).create({
        content: this.get(property)
      });
    }.property(property),

    rollbackBuffer: function() {
      this.get('buffered').discardBufferedChanges();
    },

    commitBuffer: function() {
      this.get('buffered').applyBufferedChanges();
    }
  });
}

export default bufferedProperty('content');
