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

  shouldRerender: Discourse.View.renderIfChanged('topic.details.auto_close_at'),

  render: function(buffer) {
    if (!this.present('topic.details.auto_close_at')) return;

    var autoCloseAt = moment(this.get('topic.details.auto_close_at'));

    if (autoCloseAt < new Date()) return;

    var duration = moment.duration(autoCloseAt - moment());

    var timeLeftString, rerenderDelay, minutesLeft = duration.asMinutes();

    if (minutesLeft > 1410) {
      timeLeftString = I18n.t('in_n_days', {count: Math.round(duration.asDays())});
      if( minutesLeft > 2160 ) {
        rerenderDelay = 12 * 60 * 60000;
      } else {
        rerenderDelay = 60 * 60000;
      }
    } else if (minutesLeft > 90) {
      timeLeftString = I18n.t('in_n_hours', {count: Math.round(duration.asHours())});
      rerenderDelay = 30 * 60000;
    } else if (minutesLeft > 2) {
      timeLeftString = I18n.t('in_n_minutes', {count: Math.round(duration.asMinutes())});
      rerenderDelay = 60000;
    } else {
      timeLeftString = I18n.t('in_n_seconds', {count: Math.round(duration.asSeconds())});
      rerenderDelay = 1000;
    }

    buffer.push('<h3><i class="icon icon-time"></i> ');
    buffer.push( I18n.t('topic.auto_close_notice', {timeLeft: timeLeftString}) );
    buffer.push('</h3>');

    // TODO Sam: concerned this can cause a heavy rerender loop
    this.set('delayedRerender', Em.run.later(this, this.rerender, rerenderDelay));
  },

  willDestroyElement: function() {
    if( this.delayedRerender ) {
      Em.run.cancel(this.get('delayedRerender'));
    }
  }
});
