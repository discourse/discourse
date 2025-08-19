import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { gt, readOnly } from "@ember/object/computed";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import CountI18n from "discourse/components/count-i18n";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import WebhookEvent from "admin/components/webhook-event";
import ComboBox from "select-kit/components/combo-box";

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

  <template>
    <div
      class="web-hook-events-listing"
      {{didInsert this.subscribe}}
      {{didUpdate this.reloadEvents @status}}
      {{willDestroy this.unsubscribe}}
    >
      <div class="web-hook-events-actions">
        <ComboBox
          @value={{@status}}
          @content={{this.statuses}}
          @onChange={{fn (mut @status)}}
          @options={{hash none="admin.web_hooks.events.filter_status.all"}}
          class="delivery-status-filters"
        />

        <DButton
          @icon="arrows-rotate"
          @label="admin.web_hooks.events.redeliver_failed"
          @action={{this.redeliverFailed}}
          @disabled={{not this.redeliverEnabled}}
        />

        <DButton
          @icon="paper-plane"
          @label="admin.web_hooks.events.ping"
          @action={{this.ping}}
          @disabled={{not this.pingEnabled}}
          class="webhook-events__ping-button"
        />
      </div>

      {{#if this.events}}
        <LoadMore @action={{this.loadMore}}>
          <div class="web-hook-events content-list">
            <div class="heading-container">
              <div class="col heading first status">
                {{i18n "admin.web_hooks.events.status"}}
              </div>
              <div class="col heading event-id">
                {{i18n "admin.web_hooks.events.event_id"}}
              </div>
              <div class="col heading timestamp">
                {{i18n "admin.web_hooks.events.timestamp"}}
              </div>
              <div class="col heading completion">
                {{i18n "admin.web_hooks.events.completion"}}
              </div>
              <div class="col heading actions">
                {{i18n "admin.web_hooks.events.actions"}}
              </div>
            </div>

            {{#if this.hasIncoming}}
              <a
                href
                tabindex="0"
                {{on "click" this.showInserted}}
                class="alert alert-info clickable"
              >
                <CountI18n
                  @key="admin.web_hooks.events.incoming"
                  @count={{this.incomingCount}}
                />
              </a>
            {{/if}}

            <ul>
              {{#each this.events as |event|}}
                <WebhookEvent @event={{event}} />
              {{/each}}
            </ul>
          </div>

          <ConditionalLoadingSpinner @condition={{this.events.loadingMore}} />
        </LoadMore>
      {{else}}
        <p>{{i18n "admin.web_hooks.events.none"}}</p>
      {{/if}}
    </div>
  </template>
}
