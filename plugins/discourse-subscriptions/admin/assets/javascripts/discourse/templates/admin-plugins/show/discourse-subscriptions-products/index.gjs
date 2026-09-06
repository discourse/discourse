import { LinkTo } from "@ember/routing";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import formatUnixDate from "discourse/plugins/discourse-subscriptions/discourse/helpers/format-unix-date";
import SubscriptionsStripeUnconfigured from "../../../../components/subscriptions-stripe-unconfigured";

export default <template>
  {{#if @controller.model.unconfigured}}
    <SubscriptionsStripeUnconfigured />
  {{else}}
    <p class="btn-right">
      <LinkTo
        @route="adminPlugins.show.discourse-subscriptions-products.show"
        @model="new"
        class="btn btn-primary"
      >
        {{dIcon "plus"}}
        <span>
          {{i18n "discourse_subscriptions.admin.products.operations.new"}}
        </span>
      </LinkTo>
    </p>

    {{#if @controller.model}}
      <table class="table discourse-patrons-table">
        <thead>
          <th>
            {{i18n "discourse_subscriptions.admin.products.product.name"}}
          </th>
          <th>
            {{i18n "discourse_subscriptions.admin.products.product.created_at"}}
          </th>
          <th>
            {{i18n "discourse_subscriptions.admin.products.product.updated_at"}}
          </th>
          <th class="td-right">
            {{i18n "discourse_subscriptions.admin.products.product.active"}}
          </th>
          <th></th>
        </thead>

        <tbody>
          {{#each @controller.model as |product|}}
            <tr>
              <td>{{product.name}}</td>
              <td>{{formatUnixDate product.created}}</td>
              <td>{{formatUnixDate product.updated}}</td>
              <td class="td-right">{{product.active}}</td>
              <td class="td-right">
                <div class="align-buttons">
                  <LinkTo
                    @route="adminPlugins.show.discourse-subscriptions-products.show"
                    @model={{product.id}}
                    class="btn no-text btn-icon"
                  >
                    {{dIcon "far-pen-to-square"}}
                  </LinkTo>

                  <DButton
                    @action={{routeAction "destroyProduct"}}
                    @actionParam={{product}}
                    @icon="trash-can"
                    class="btn-danger btn no-text btn-icon"
                  />
                </div>
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <p>
        {{i18n "discourse_subscriptions.admin.products.product_help"}}
      </p>
    {{/if}}
  {{/if}}
</template>
