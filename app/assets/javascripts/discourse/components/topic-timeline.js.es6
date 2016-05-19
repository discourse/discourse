import MountWidget from 'discourse/components/mount-widget';
import Docking from 'discourse/mixins/docking';

export default MountWidget.extend(Docking, {
  widget: 'topic-timeline-container',
  dockAt: null,

  buildArgs() {
    return { topic: this.get('topic'),
             topicTrackingState: this.topicTrackingState,
             dockAt: this.dockAt };
  },

  dockCheck(info) {
    const topicBottom = $('#topic-bottom').offset().top;
    const $timeline = this.$('.timeline-container');
    const timelineHeight = $timeline.height();

    const tTop = 140;

    const prev = this.dockAt;
    const pos = tTop + info.offset() + timelineHeight;
    if (pos > topicBottom) {
      this.dockAt = topicBottom - timelineHeight - $timeline.offsetParent().offset().top;
    } else {
      this.dockAt = null;
    }

    if (this.dockAt !== prev) {
      this.queueRerender();
    }
  },

  didInsertElement() {
    this._super();
    this.dispatch('topic:current-post-changed', 'timeline-scrollarea');
  },

  willDestroyElement() {
    this._super();
    this.appEvents.off('topic:current-post-changed');
  }
});
