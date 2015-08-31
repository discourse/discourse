import Eyeline from 'discourse/lib/eyeline';
import Scrolling from 'discourse/mixins/scrolling';

//  Provides the ability to load more items for a view which is scrolled to the bottom.
export default Ember.Mixin.create(Ember.ViewTargetActionSupport, Scrolling, {

  scrolled() {
    const eyeline = this.get('eyeline');
    if (eyeline) { eyeline.update(); }
  },

  _bindEyeline: function() {
    const eyeline = new Eyeline(this.get('eyelineSelector') + ":last");
    this.set('eyeline', eyeline);
    eyeline.on('sawBottom', () => this.send('loadMore'));
    this.bindScrolling();
  }.on('didInsertElement'),

  _removeEyeline: function() {
    this.unbindScrolling();
  }.on('willDestroyElement')

});
