import MountWidget from 'discourse/components/mount-widget';
import Docking from 'discourse/mixins/docking';
import { observes } from 'ember-addons/ember-computed-decorators';

const FIXED_POS = 85;

export default MountWidget.extend(Docking, {
  widget: 'topic-timeline-container',
  dockBottom: null,
  dockAt: null,

  buildArgs() {
    let attrs =  {
      topic: this.get('topic'),
      topicTrackingState: this.topicTrackingState,
      enteredIndex: this.get('enteredIndex'),
      dockBottom: this.dockBottom,
      mobileView: this.get('site.mobileView')
    };

    let event = this.get('prevEvent');
    if (event) {
      attrs.enteredIndex = event.postIndex-1;
    }

    if (this.get('fullscreen')) {
      attrs.fullScreen = true;
      attrs.addShowClass = this.get('addShowClass');
    } else {
      attrs.dockAt = this.dockAt;
      attrs.top = this.dockAt || FIXED_POS;
    }

    return attrs;
  },

  @observes('topic.highest_post_number', 'loading')
  newPostAdded() {
    this.queueRerender(() => this.queueDockCheck());
  },

  dockCheck(info) {
    const mainOffset = $('#main').offset();
    const offsetTop = mainOffset ? mainOffset.top : 0;
    const topicTop = $('.container.posts').offset().top - offsetTop;
    const topicBottom = $('#topic-bottom').offset().top;
    const $timeline = this.$('.timeline-container');
    const timelineHeight = $timeline.height() || 400;
    const footerHeight = $('.timeline-footer-controls').outerHeight(true) || 0;

    const prev = this.dockAt;
    const posTop = FIXED_POS + info.offset();
    const pos = posTop + timelineHeight;

    this.dockBottom = false;
    if (posTop < topicTop) {
      this.dockAt = topicTop;
    } else if (pos > topicBottom + footerHeight) {
      this.dockAt = (topicBottom - timelineHeight) + footerHeight;
      this.dockBottom = true;
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

    if (this.get('fullscreen') && !this.get('addShowClass')) {
      Em.run.next(()=>{
        this.set('addShowClass', true);
        this.queueRerender();
      });
    }

    this.dispatch('topic:current-post-scrolled', 'timeline-scrollarea');
    this.dispatch('topic-notifications-button:changed', 'topic-notifications-button');
  }
});
