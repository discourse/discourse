import MountWidget from 'discourse/components/mount-widget';
import { observes } from 'ember-addons/ember-computed-decorators';

export default MountWidget.extend({
  widget: 'topic-notifications-button',

  buildArgs() {
    return { topic: this.get('topic'), appendReason: true, showFullTitle: true };
  },

  @observes('topic.details.notification_level')
  _triggerRerender() {
    this.queueRerender();
  }
});
