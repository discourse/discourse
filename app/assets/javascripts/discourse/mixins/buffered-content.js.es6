/* global BufferedProxy: true */
export default Ember.Mixin.create({
  buffered: function() {
    return Em.ObjectProxy.extend(BufferedProxy).create({
      content: this.get('content')
    });
  }.property('content'),

  rollbackBuffer: function() {
    this.get('buffered').discardBufferedChanges();
  },

  commitBuffer: function() {
    this.get('buffered').applyBufferedChanges();
  }
});
