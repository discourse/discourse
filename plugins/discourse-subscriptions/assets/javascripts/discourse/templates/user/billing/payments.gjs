import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";
import formatCurrency from "../../../helpers/format-currency";
import formatUnixDate from "../../../helpers/format-unix-date";

export default RouteTemplate(
  <template>
    {{#if @controller.model}}
      <table class="table discourse-subscriptions-user-table">
        <thead>
          <th>{{i18n "discourse_subscriptions.user.payments.id"}}</th>
          <th>{{i18n "discourse_subscriptions.user.payments.amount"}}</th>
          <th>{{i18n "discourse_subscriptions.user.payments.created_at"}}</th>
        </thead>
        <tbody>
          {{#each @controller.model as |payment|}}
            <tr>
              <td>{{payment.id}}</td>
              <td>{{formatCurrency payment.currency payment.amountDollars}}</td>
              <td>{{formatUnixDate payment.created}}</td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <div class="alert alert-info">
        {{i18n "discourse_subscriptions.user.payments_help"}}
      </div>
    {{/if}}
  </template>
);
