import MountWidget from 'discourse/components/mount-widget';
import Docking from 'discourse/mixins/docking';
import { observes } from 'ember-addons/ember-computed-decorators';

export default MountWidget.extend(Docking, {
  widget: 'topic-timeline-container',
  dockAt: null,

  buildArgs() {
    return { topic: this.get('topic'),
             topicTrackingState: this.topicTrackingState,
             enteredIndex: this.get('enteredIndex'),
             dockAt: this.dockAt };
  },

  @observes('topic.highest_post_number')
  newPostAdded() {
    this.queueRerender(() => this.queueDockCheck());
  },

  dockCheck(info) {
    if (this.get('loading')) { return; }

    const topicTop = $('.container.posts').offset().top;
    const topicBottom = $('#topic-bottom').offset().top;
    const $timeline = this.$('.timeline-container');
    const timelineHeight = $timeline.height();
    const parentTop = $('.posts-wrapper').offset().top;

    const tTop = 140;

    const prev = this.dockAt;
    const posTop = tTop + info.offset();
    const pos = posTop + timelineHeight;

    if (posTop < topicTop) {
      this.dockAt = 0;
    } else if (pos > topicBottom) {
      this.dockAt = topicBottom - timelineHeight - parentTop;
      if (this.dockAt < 0) { this.dockAt = 0; }
    } else {
      this.dockAt = null;
    }

    if (this.dockAt !== prev) {
      this.queueRerender();
    }
  },

  didInsertElement() {
    this._super();
    this.dispatch('topic:current-post-scrolled', 'timeline-scrollarea');
  },

  willDestroyElement() {
    this._super();
    this.appEvents.off('topic:current-post-scrolled');
  }
});
