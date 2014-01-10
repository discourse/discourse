/**
  This mixin provides the ability to load more items for a view which is
  scrolled to the bottom.

  @class Discourse.LoadMore
  @extends Ember.Mixin
  @uses Discourse.Scrolling
  @namespace Discourse
  @module Discourse
**/
Discourse.LoadMore = Em.Mixin.create(Ember.ViewTargetActionSupport, Discourse.Scrolling, {

  scrolled: function() {
    var eyeline = this.get('eyeline');
    if (eyeline) { eyeline.update(); }
  },

  didInsertElement: function() {
    this._super();
    var eyeline = new Discourse.Eyeline(this.get('eyelineSelector'));
    this.set('eyeline', eyeline);

    var self = this;
    eyeline.on('sawBottom', function() {
      self.send('loadMore');
    });
    this.bindScrolling();
  },

  willDestroyElement: function() {
    this._super();
    this.unbindScrolling();
  }

});
