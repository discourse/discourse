import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import loadingSpinner from "discourse/helpers/loading-spinner";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import formatUnixDate from "../../../../helpers/format-unix-date";

export default RouteTemplate(
  <template>
    {{#if @controller.model}}
      <table class="table discourse-subscriptions-user-table">
        <thead>
          <th>{{i18n "discourse_subscriptions.user.subscriptions.id"}}</th>
          <th>{{i18n "discourse_subscriptions.user.plans.product"}}</th>
          <th>{{i18n "discourse_subscriptions.user.plans.rate"}}</th>
          <th>{{i18n
              "discourse_subscriptions.user.subscriptions.discounted"
            }}</th>
          <th>{{i18n "discourse_subscriptions.user.subscriptions.status"}}</th>
          <th>{{i18n "discourse_subscriptions.user.subscriptions.renews"}}</th>
          <th>{{i18n
              "discourse_subscriptions.user.subscriptions.created_at"
            }}</th>
          <th></th>
        </thead>
        <tbody>
          {{#each @controller.model as |subscription|}}
            <tr>
              <td>{{subscription.id}}</td>
              <td>{{subscription.product.name}}</td>
              <td>{{subscription.plan.subscriptionRate}}</td>
              <td>{{subscription.discounted}}</td>
              <td>{{subscription.status}}</td>
              <td>{{subscription.endDate}}</td>
              <td>{{formatUnixDate subscription.created}}</td>
              <td class="td-right">
                {{#if subscription.loading}}
                  {{loadingSpinner size="small"}}
                {{else}}
                  {{#if subscription.canceled_at}}
                    <DButton
                      @disabled={{subscription.canceled_at}}
                      @label="discourse_subscriptions.user.subscriptions.cancelled"
                    />
                  {{else}}
                    <DButton
                      @action={{routeAction "updateCard" subscription.id}}
                      @icon="far-pen-to-square"
                      class="btn no-text btn-icon"
                    />
                    <DButton
                      class="btn-danger btn no-text btn-icon"
                      @icon="trash-can"
                      @disabled={{subscription.canceled_at}}
                      @action={{routeAction "cancelSubscription" subscription}}
                    />
                  {{/if}}
                {{/if}}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <div class="alert alert-info">
        {{i18n "discourse_subscriptions.user.subscriptions_help"}}
      </div>
    {{/if}}
  </template>
);
