import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminConfigAreaEmptyList from "admin/components/admin-config-area-empty-list";
import WebhookItem from "admin/components/webhook-item";

export default class AdminConfigAreasWebhooksList extends Component {
  @service dialog;

  @tracked webhooks = this.args.webhooks;

  @action
  destroyWebhook(webhook) {
    return this.dialog.deleteConfirm({
      message: i18n("admin.web_hooks.delete_confirm"),
      didConfirm: async () => {
        try {
          await webhook.destroyRecord();
          this.webhooks.removeObject(webhook);
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  <template>
    <div class="container admin-api_keys">
      {{#if this.webhooks}}
        <table class="d-table admin-web_hooks__items">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell">{{i18n
                  "admin.web_hooks.delivery_status.title"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "admin.web_hooks.payload_url"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "admin.web_hooks.description_label"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "admin.web_hooks.controls"
                }}</th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each this.webhooks as |webhook|}}
              <WebhookItem
                @webhook={{webhook}}
                @deliveryStatuses={{this.webhooks.extras.delivery_statuses}}
                @destroy={{this.destroyWebhook}}
              />
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList
          @ctaLabel="admin.web_hooks.add"
          @ctaRoute="adminWebHooks.new"
          @ctaClass="admin-web_hooks__add-web_hook"
          @emptyLabel="admin.web_hooks.none"
        />
      {{/if}}
    </div>
  </template>
}
