import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  pingDisabled: false,

  addIncoming(eventId) {
    if (this.incomingEventIds.indexOf(eventId) === -1) {
      this.incomingEventIds.push(eventId);
    }
  },

  resetIncoming() {
    this.incomingEventIds = [];
    this.set('incomingCount', 0);
  },

  @computed('incomingCount')
  hasIncoming(incomingCount) {
    return incomingCount && incomingCount > 0;
  },

  subscribe() {
    this.unsubscribe();

    this.messageBus.subscribe(`/web_hook_events/${this.get('model.extras.web_hook_id')}`, data => {
      if (data.event_type === 'ping') {
        this.set('pingDisabled', false);
      }
      this.addIncoming(data.web_hook_event_id);
      this.set('incomingCount', this.incomingEventIds.length);
    });
  },

  unsubscribe() {
    this.messageBus.unsubscribe('/web_hook_events/*');
    this.resetIncoming();
  },

  actions: {
    loadMore() {
      this.get('model').loadMore();
    },

    ping() {
      this.set('pingDisabled', true);
      ajax(`/admin/web_hooks/${this.get('model.extras.web_hook_id')}/ping`, {type: 'POST'}).catch(error => {
        this.set('pingDisabled', false);
        popupAjaxError(error);
      });
    },

    showInserted() {
      const webHookId = this.get('model.extras.web_hook_id'),
        eventIds = this.incomingEventIds.sort().reverse().join(',');
      ajax(`/admin/web_hooks/${webHookId}/events/bulk?ids=${eventIds}`, {type: 'GET'}).then(json => {
        let content = Ember.A(json['web_hook_events'].map(event => this.store.createRecord('web-hook-event', event)));
        content.pushObjects(this.get('model.content'));
        this.set('model.content', content);
        this.resetIncoming();
      });

      return false;
    }
  }
});
