/**
  This view is used for rendering the notification that a topic will
  automatically close.

  @class TopicClosingView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicClosingView = Discourse.View.extend({
  elementId: 'topic-closing-info',
  delayedRerender: null,

  contentChanged: function() {
    this.rerender();
  }.observes('topic.auto_close_at'),

  render: function(buffer) {
    if (!this.present('topic.auto_close_at')) return;

    var autoCloseAt = Date.create(this.get('topic.auto_close_at'));

    if (autoCloseAt.isPast()) return;

    var timeLeftString, reRenderDelay, minutesLeft = autoCloseAt.minutesSince();

    if (minutesLeft > 1440) {
      timeLeftString = Em.String.i18n('in_n_days', {count: autoCloseAt.daysSince()});
      if( minutesLeft > 2160 ) {
        reRenderDelay = 12 * 60 * 60000;
      } else {
        reRenderDelay = 60 * 60000;
      }
    } else if (minutesLeft > 90) {
      timeLeftString = Em.String.i18n('in_n_hours', {count: autoCloseAt.hoursSince()});
      reRenderDelay = 30 * 60000;
    } else if (minutesLeft > 2) {
      timeLeftString = Em.String.i18n('in_n_minutes', {count: autoCloseAt.minutesSince()});
      reRenderDelay = 60000;
    } else {
      timeLeftString = Em.String.i18n('in_n_seconds', {count: autoCloseAt.secondsSince()});
      reRenderDelay = 1000;
    }

    buffer.push('<h3><i class="icon icon-time"></i> ');
    buffer.push( Em.String.i18n('topic.auto_close_notice', {timeLeft: timeLeftString}) );
    buffer.push('</h3>');

    this.delayedRerender = this.rerender.bind(this).delay(reRenderDelay);
  },

  willDestroyElement: function() {
    if( this.delayedRerender ) {
      this.delayedRerender.cancel();
    }
  }
});