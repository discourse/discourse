import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { gt, readOnly } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

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
  }

  get statuses() {
    return [
      {
        id: "successful",
        name: I18n.t("admin.web_hooks.events.filter_status.successful"),
      },
      {
        id: "failed",
        name: I18n.t("admin.web_hooks.events.filter_status.failed"),
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
