import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { gt, readOnly } from "@ember/object/computed";
import { bind } from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class WebhookEvents extends Component {
  @service messageBus;
  @service store;

  @tracked pingEnabled = true;
  @tracked events = [];
  @tracked incomingEventIds = [];

  @readOnly("incomingEventIds.length") incomingCount;
  @gt("incomingCount", 0) hasIncoming;

  constructor() {
    super(...arguments);
    this.loadEvents();
  }

  async loadEvents() {
    this.events = await this.store.findAll(
      "web-hook-event",
      this.args.webhookId
    );
  }

  @bind
  subscribe() {
    const channel = `/web_hook_events/${this.args.webhookId}`;
    this.messageBus.subscribe(channel, this._addIncoming);
  }

  @bind
  unsubscribe() {
    this.messageBus.unsubscribe("/web_hook_events/*", this._addIncoming);
  }

  @bind
  _addIncoming(data) {
    if (data.event_type === "ping") {
      this.pingEnabled = true;
    }

    if (!this.incomingEventIds.includes(data.web_hook_event_id)) {
      this.incomingEventIds.pushObject(data.web_hook_event_id);
    }
  }

  @action
  async showInserted(event) {
    event?.preventDefault();

    const path = `/admin/api/web_hooks/${this.args.webhookId}/events/bulk`;
    const data = await ajax(path, {
      data: { ids: this.incomingEventIds },
    });

    const objects = data.map((webhookEvent) =>
      this.store.createRecord("web-hook-event", webhookEvent)
    );
    this.events.unshiftObjects(objects);
    this.incomingEventIds = [];
  }

  @action
  loadMore() {
    this.events.loadMore();
  }

  @action
  async ping() {
    this.pingEnabled = false;

    try {
      await ajax(`/admin/api/web_hooks/${this.args.webhookId}/ping`, {
        type: "POST",
      });
    } catch (error) {
      this.pingEnabled = true;
      popupAjaxError(error);
    }
  }
}
