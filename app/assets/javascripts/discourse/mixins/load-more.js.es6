import Eyeline from 'discourse/lib/eyeline';
import Scrolling from 'discourse/mixins/scrolling';
import { on } from 'ember-addons/ember-computed-decorators';

//  Provides the ability to load more items for a view which is scrolled to the bottom.
export default Ember.Mixin.create(Ember.ViewTargetActionSupport, Scrolling, {

  scrolled() {
    const eyeline = this.get('eyeline');
    if (eyeline) { eyeline.update(); }
  },

  loadMoreUnlessFull() {
    if (this.screenNotFull()) {
      this.send("loadMore");
    }
  },

  @on("didInsertElement")
  _bindEyeline() {
    const eyeline = new Eyeline(this.get('eyelineSelector') + ":last");
    this.set('eyeline', eyeline);
    eyeline.on('sawBottom', () => this.send('loadMore'));
    this.bindScrolling();
  },

  @on("willDestroyElement")
  _removeEyeline() {
    this.unbindScrolling();
  }

});
