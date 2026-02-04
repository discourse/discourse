import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import WebhookItem from "discourse/admin/components/webhook-item";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasWebhooksList extends Component {
  @service dialog;

  @action
  destroyWebhook(webhook) {
    return this.dialog.deleteConfirm({
      message: i18n("admin.web_hooks.delete_confirm"),
      didConfirm: async () => {
        try {
          await webhook.destroyRecord();
          removeValueFromArray(this.args.webhooks.content, webhook);
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  <template>
    <div class="container admin-api_keys">
      {{#if @webhooks.content}}
        <LoadMore @action={{@webhooks.loadMore}}>
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
              {{#each @webhooks.content as |webhook|}}
                <WebhookItem
                  @webhook={{webhook}}
                  @deliveryStatuses={{@webhooks.extras.delivery_statuses}}
                  @destroy={{this.destroyWebhook}}
                />
              {{/each}}
              {{#if @webhooks.loadingMore}}
                <tr class="d-table__row">
                  <td class="d-table__cell" colspan="4">
                    <ConditionalLoadingSpinner
                      @condition={{@webhooks.loadingMore}}
                    />
                  </td>
                </tr>
              {{/if}}
            </tbody>
          </table>
        </LoadMore>
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
