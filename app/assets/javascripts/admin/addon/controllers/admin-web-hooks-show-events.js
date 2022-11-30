import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  pingDisabled: false,
  incomingCount: alias("incomingEventIds.length"),

  init() {
    this._super(...arguments);

    this.incomingEventIds = [];
  },

  @discourseComputed("incomingCount")
  hasIncoming(incomingCount) {
    return incomingCount > 0;
  },

  subscribe() {
    this.messageBus.subscribe(
      `/web_hook_events/${this.get("model.extras.web_hook_id")}`,
      this._addIncoming
    );
  },

  unsubscribe() {
    this.messageBus.unsubscribe("/web_hook_events/*", this._addIncoming);
  },

  @bind
  _addIncoming(data) {
    if (data.event_type === "ping") {
      this.set("pingDisabled", false);
    }

    if (!this.incomingEventIds.includes(data.web_hook_event_id)) {
      this.incomingEventIds.pushObject(data.web_hook_event_id);
    }
  },

  @action
  showInserted(event) {
    event?.preventDefault();
    const webHookId = this.get("model.extras.web_hook_id");

    ajax(`/admin/api/web_hooks/${webHookId}/events/bulk`, {
      type: "GET",
      data: { ids: this.incomingEventIds },
    }).then((data) => {
      const objects = data.map((webHookEvent) =>
        this.store.createRecord("web-hook-event", webHookEvent)
      );
      this.model.unshiftObjects(objects);
      this.set("incomingEventIds", []);
    });
  },

  actions: {
    loadMore() {
      this.model.loadMore();
    },

    ping() {
      this.set("pingDisabled", true);

      ajax(
        `/admin/api/web_hooks/${this.get("model.extras.web_hook_id")}/ping`,
        {
          type: "POST",
        }
      ).catch((error) => {
        this.set("pingDisabled", false);
        popupAjaxError(error);
      });
    },
  },
});
