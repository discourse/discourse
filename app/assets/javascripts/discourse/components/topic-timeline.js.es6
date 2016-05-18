import MountWidget from 'discourse/components/mount-widget';
import computed from 'ember-addons/ember-computed-decorators';

export default MountWidget.extend({
  widget: 'topic-timeline',

  @computed('topic')
  args(topic) {
    return { topic, topicTrackingState: this.topicTrackingState };
  },

  didInsertElement() {
    this._super();
    this.dispatch('topic:current-post-changed', 'timeline-scrollarea');
  }
});
