/**
  Handles a gap between posts with a click to load more

  @class PostGapComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
export default Ember.Component.extend({
  classNameBindings: [':gap', 'gap::hidden'],

  initGaps: function(){
    this.set('loading', false);
    var before = this.get('before') === 'true',
        gaps = before ? this.get('postStream.gaps.before') : this.get('postStream.gaps.after');

    if (gaps) {
      this.set('gap', gaps[this.get('post.id')]);
    }
  }.on('init'),

  gapsChanged: function(){
    this.initGaps();
    this.rerender();
  }.observes('post.hasGap'),

  render: function(buffer) {
    if (this.get('loading')) {
      buffer.push(I18n.t('loading'));
    } else {
      var gapLength = this.get('gap.length');
      if (gapLength) {
        buffer.push(I18n.t('post.gap', {count: gapLength}));
      }
    }
  },

  click: function() {
    if (this.get('loading') || (!this.get('gap'))) { return false; }
    this.set('loading', true);
    this.rerender();

    var self = this,
        postStream = this.get('postStream'),
        filler = this.get('before') === 'true' ? postStream.fillGapBefore : postStream.fillGapAfter;

    filler.call(postStream, this.get('post'), this.get('gap')).then(function() {
      // hide this control after the promise is resolved
      self.set('gap', null);
    });

    return false;
  }
});
