import MountWidget from 'discourse/components/mount-widget';
import { observes } from 'ember-addons/ember-computed-decorators';

export default MountWidget.extend({
  widget: 'topic-notifications-button',

  buildArgs() {
    return { topic: this.get('topic'), appendReason: true, showFullTitle: true };
  },

  @observes('topic.details.notification_level')
  _triggerEvent() {
    this.appEvents.trigger('topic-notifications-button:changed', {
      type: 'notification', id: this.get('topic.details.notification_level')
    });
  },

  didInsertElement() {
    this._super();
    this.dispatch('topic-notifications-button:changed', 'topic-notifications-button');
  }
});
