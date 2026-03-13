import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CalendarSubscriptionUrl from "discourse/components/calendar-subscription-url";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class CalendarSubscriptions extends Component {
  @service dialog;

  @tracked hasSubscription = null;
  @tracked urls = null;
  @tracked loading = false;

  constructor() {
    super(...arguments);
    this.loadStatus();
  }

  async loadStatus() {
    try {
      const result = await ajax("/calendar-subscriptions.json");
      this.hasSubscription = result.has_subscription;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async generateUrls() {
    this.loading = true;
    try {
      const result = await ajax("/calendar-subscriptions.json", {
        type: "POST",
      });
      this.urls = result.urls;
      this.hasSubscription = true;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  regenerateUrls() {
    this.dialog.confirm({
      message: i18n("user.calendar_subscriptions.regenerate_confirm"),
      didConfirm: () => this.generateUrls(),
    });
  }

  @action
  revokeSubscription() {
    this.dialog.confirm({
      message: i18n("user.calendar_subscriptions.revoke_confirm"),
      didConfirm: async () => {
        try {
          await ajax("/calendar-subscriptions.json", {
            type: "DELETE",
          });
          this.hasSubscription = false;
          this.urls = null;
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  <template>
    <div class="calendar-subscriptions">
      <p class="calendar-subscriptions__description">
        {{i18n "user.calendar_subscriptions.description"}}
      </p>

      {{#if this.urls}}
        <div class="calendar-subscriptions__urls">
          <div class="alert alert-info calendar-subscriptions__warning">
            {{icon "triangle-exclamation"}}
            {{i18n "user.calendar_subscriptions.urls_warning"}}
          </div>

          <CalendarSubscriptionUrl
            @label={{i18n "user.calendar_subscriptions.bookmarks"}}
            @description={{i18n
              "user.calendar_subscriptions.bookmarks_description"
            }}
            @url={{this.urls.bookmarks}}
          />

          <PluginOutlet
            @name="calendar-subscriptions-feeds"
            @outletArgs={{lazyHash urls=this.urls}}
          />

          <div class="calendar-subscriptions__actions">
            <DButton
              @action={{this.revokeSubscription}}
              @label="user.calendar_subscriptions.revoke"
              class="btn-danger"
            />
          </div>
        </div>
      {{else if this.hasSubscription}}
        <div class="calendar-subscriptions__active">
          <p class="calendar-subscriptions__active-status">
            {{icon "check"}}
            {{i18n "user.calendar_subscriptions.active_subscription"}}
          </p>
          <div class="calendar-subscriptions__actions">
            <DButton
              @action={{this.regenerateUrls}}
              @icon="arrows-rotate"
              @label="user.calendar_subscriptions.regenerate"
              @isLoading={{this.loading}}
              class="btn-primary"
            />
            <DButton
              @action={{this.revokeSubscription}}
              @label="user.calendar_subscriptions.revoke"
              class="btn-danger"
            />
          </div>
        </div>
      {{else if (eq this.hasSubscription false)}}
        <DButton
          @action={{this.generateUrls}}
          @icon="calendar-days"
          @label="user.calendar_subscriptions.generate"
          @isLoading={{this.loading}}
          class="btn-primary"
        />
      {{/if}}
    </div>
  </template>
}
