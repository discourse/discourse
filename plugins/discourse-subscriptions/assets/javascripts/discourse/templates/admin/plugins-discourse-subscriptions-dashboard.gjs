import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import LoadMore from "discourse/components/load-more";
import formatDuration from "discourse/helpers/format-duration";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <h3>{{i18n "discourse_subscriptions.admin.dashboard.title"}}</h3>

    <LoadMore
      @selector=".discourse-patrons-table tr"
      @action={{@controller.loadMore}}
    >
      {{#if @controller.model}}
        <table class="table discourse-patrons-table">
          <thead>
            <tr>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.dashboard.table.head.user"
                }}
              </th>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.dashboard.table.head.payment_intent"
                }}
              </th>
              <th>
                {{i18n
                  "discourse_subscriptions.admin.dashboard.table.head.receipt_email"
                }}
              </th>
              <th
                {{on "click" (fn @controller.orderPayments "created_at")}}
                role="button"
                class="sortable"
              >
                {{i18n "created"}}
              </th>
              <th
                {{on "click" (fn @controller.orderPayments "amount")}}
                role="button"
                class="sortable amount"
              >
                {{i18n
                  "discourse_subscriptions.admin.dashboard.table.head.amount"
                }}
              </th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.model as |payment|}}
              <tr>
                <td>
                  <LinkTo
                    @route="adminUser.index"
                    @models={{array payment.user_id payment.username}}
                  >
                    {{payment.username}}
                  </LinkTo>
                </td>
                <td>
                  <LinkTo
                    @route="patrons.show"
                    @model={{payment.payment_intent_id}}
                  >
                    {{htmlSafe payment.payment_intent_id}}
                  </LinkTo>
                </td>
                <td>{{payment.receipt_email}}</td>
                <td>{{htmlSafe (formatDuration payment.created_at_age)}}</td>
                <td class="amount">{{payment.amount_currency}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{/if}}
    </LoadMore>
  </template>
);
