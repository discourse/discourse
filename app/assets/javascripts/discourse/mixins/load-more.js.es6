//  Provides the ability to load more items for a view which is scrolled to the bottom.
export default Em.Mixin.create(Ember.ViewTargetActionSupport, Discourse.Scrolling, {

  scrolled: function() {
    const eyeline = this.get('eyeline');
    if (eyeline) { eyeline.update(); }
  },

  _bindEyeline: function() {
    const eyeline = new Discourse.Eyeline(this.get('eyelineSelector') + ":last");
    this.set('eyeline', eyeline);
    eyeline.on('sawBottom', () => this.send('loadMore'));
    this.bindScrolling();
  }.on('didInsertElement'),

  _removeEyeline: function() {
    this.unbindScrolling();
  }.on('willDestroyElement')

});
