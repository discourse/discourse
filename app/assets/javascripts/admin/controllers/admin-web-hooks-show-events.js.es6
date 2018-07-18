import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  pingDisabled: false,
  incomingEventIds: [],
  incomingCount: Ember.computed.alias("incomingEventIds.length"),

  @computed("incomingCount")
  hasIncoming(incomingCount) {
    return incomingCount > 0;
  },

  subscribe() {
    this.messageBus.subscribe(
      `/web_hook_events/${this.get("model.extras.web_hook_id")}`,
      data => {
        if (data.event_type === "ping") {
          this.set("pingDisabled", false);
        }
        this._addIncoming(data.web_hook_event_id);
      }
    );
  },

  unsubscribe() {
    this.messageBus.unsubscribe("/web_hook_events/*");
  },

  _addIncoming(eventId) {
    const incomingEventIds = this.get("incomingEventIds");

    if (incomingEventIds.indexOf(eventId) === -1) {
      incomingEventIds.pushObject(eventId);
    }
  },

  actions: {
    loadMore() {
      this.get("model").loadMore();
    },

    ping() {
      this.set("pingDisabled", true);

      ajax(
        `/admin/api/web_hooks/${this.get("model.extras.web_hook_id")}/ping`,
        {
          type: "POST"
        }
      ).catch(error => {
        this.set("pingDisabled", false);
        popupAjaxError(error);
      });
    },

    showInserted() {
      const webHookId = this.get("model.extras.web_hook_id");

      ajax(`/admin/api/web_hooks/${webHookId}/events/bulk`, {
        type: "GET",
        data: { ids: this.get("incomingEventIds") }
      }).then(data => {
        const objects = data.map(event =>
          this.store.createRecord("web-hook-event", event)
        );
        this.get("model").unshiftObjects(objects);
        this.set("incomingEventIds", []);
      });
    }
  }
});
