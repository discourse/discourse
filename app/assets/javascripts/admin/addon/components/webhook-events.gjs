import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { gt, readOnly } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class WebhookEvents extends Component {
  @service messageBus;
  @service store;
  @service dialog;

  @tracked pingEnabled = true;
  @tracked events = [];
  @tracked incomingEventIds = [];
  @tracked redeliverEnabled = true;

  @readOnly("incomingEventIds.length") incomingCount;
  @gt("incomingCount", 0) hasIncoming;

  constructor() {
    super(...arguments);
    this.loadEvents();
  }

  async loadEvents() {
    this.loading = true;

    try {
      this.events = await this.store.findAll("web-hook-event", {
        webhookId: this.args.webhookId,
        status: this.args.status,
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }

    this.redeliverEnabled = this.failedEventIds.length;
  }

  get failedEventIds() {
    return this.events.content
      .filter(
        (event) =>
          (event.status < 200 || event.status > 299) && event.status !== 0
      )
      .map((event) => event.id);
  }

  get statuses() {
    return [
      {
        id: "successful",
        name: i18n("admin.web_hooks.events.filter_status.successful"),
      },
      {
        id: "failed",
        name: i18n("admin.web_hooks.events.filter_status.failed"),
      },
    ];
  }

  @bind
  reloadEvents() {
    if (this.loading) {
      return;
    }

    this.loadEvents();
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

    if (data.type === "redelivered") {
      const event = this.events.find((e) => e.id === data.web_hook_event.id);

      event.setProperties({
        response_body: data.web_hook_event.response_body,
        response_headers: data.web_hook_event.response_headers,
        status: data.web_hook_event.status,
        redelivering: false,
      });
      return;
    }

    if (data.type === "redelivery_failed") {
      const event = this.events.find((e) => e.id === data.web_hook_event_id);
      event.set("redelivering", false);
      return;
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

  @action
  async redeliverFailed() {
    if (!this.failedEventIds.length) {
      this.dialog.alert(i18n("admin.web_hooks.events.no_events_to_redeliver"));
      this.redeliverEnabled = false;
      return;
    }

    return this.dialog.yesNoConfirm({
      message: i18n("admin.web_hooks.events.redeliver_failed_confirm", {
        count: this.failedEventIds.length,
      }),
      didConfirm: async () => {
        try {
          const response = await ajax(
            `/admin/api/web_hooks/${this.args.webhookId}/events/failed_redeliver`,
            { type: "POST", data: { event_ids: this.failedEventIds } }
          );
          if (response.event_ids?.length) {
            response.event_ids.map((id) => {
              const event = this.events.find((e) => e.id === id);
              event.set("redelivering", true);
            });
          } else {
            this.dialog.alert(
              i18n("admin.web_hooks.events.no_events_to_redeliver")
            );
          }
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.redeliverEnabled = false;
        }
      },
    });
  }
}
