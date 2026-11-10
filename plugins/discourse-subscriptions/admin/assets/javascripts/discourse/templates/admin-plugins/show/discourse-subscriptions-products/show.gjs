import { Input, Textarea } from "@ember/component";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import formatCurrency from "discourse/plugins/discourse-subscriptions/discourse/helpers/format-currency";
import formatUnixDate from "discourse/plugins/discourse-subscriptions/discourse/helpers/format-unix-date";

export default <template>
  <h4>{{i18n "discourse_subscriptions.admin.products.title"}}</h4>

  <form class="form-horizontal">
    <p>
      <label for="name">
        {{i18n "discourse_subscriptions.admin.products.product.name"}}
      </label>
      <Input
        name="name"
        @type="text"
        @value={{@controller.model.product.name}}
      />
    </p>

    <p>
      <label for="description">
        {{i18n "discourse_subscriptions.admin.products.product.description"}}
      </label>

      <Textarea
        class="discourse-subscriptions-admin-textarea"
        name="description"
        @value={{@controller.model.product.metadata.description}}
      />

      <div class="control-instructions">
        {{i18n
          "discourse_subscriptions.admin.products.product.description_help"
        }}
      </div>
    </p>

    <p>
      <label for="statement_descriptor">
        {{i18n
          "discourse_subscriptions.admin.products.product.statement_descriptor"
        }}
      </label>

      <Input
        name="statement_descriptor"
        @type="text"
        @value={{@controller.model.product.statement_descriptor}}
      />

      <div class="control-instructions">
        {{i18n
          "discourse_subscriptions.admin.products.product.statement_descriptor_help"
        }}
      </div>
    </p>

    <p>
      <label for="repurchaseable">
        {{i18n "discourse_subscriptions.admin.products.product.repurchaseable"}}
      </label>

      <Input
        name="repurchaseable"
        @checked={{@controller.model.product.metadata.repurchaseable}}
        @type="checkbox"
      />

      <div class="control-instructions">
        {{i18n
          "discourse_subscriptions.admin.products.product.repurchase_help"
        }}
      </div>
    </p>

    <p>
      <label for="active">
        {{i18n "discourse_subscriptions.admin.products.product.active"}}
      </label>

      <Input
        name="active"
        @checked={{@controller.model.product.active}}
        @type="checkbox"
      />

      <div class="control-instructions">
        {{i18n "discourse_subscriptions.admin.products.product.active_help"}}
      </div>
    </p>
  </form>

  {{#unless @controller.model.product.isNew}}
    <h4>{{i18n "discourse_subscriptions.admin.plans.title"}}</h4>

    <p>
      <table class="table discourse-patrons-table">
        <thead>
          <th>{{i18n "discourse_subscriptions.admin.plans.plan.nickname"}}</th>
          <th>{{i18n "discourse_subscriptions.admin.plans.plan.interval"}}</th>
          <th>{{i18n
              "discourse_subscriptions.admin.plans.plan.created_at"
            }}</th>
          <th>{{i18n "discourse_subscriptions.admin.plans.plan.group"}}</th>
          <th>{{i18n "discourse_subscriptions.admin.plans.plan.active"}}</th>
          <th class="td-right">
            {{i18n "discourse_subscriptions.admin.plans.plan.amount"}}
          </th>
          <th class="td-right">
            <LinkTo
              class="btn"
              @models={{array @controller.model.product.id "new"}}
              @route="adminPlugins.show.discourse-subscriptions-products.show.plans.show"
            >
              {{i18n "discourse_subscriptions.admin.plans.operations.add"}}
            </LinkTo>
          </th>
        </thead>

        <tbody>
          {{#each @controller.model.plans as |plan|}}
            <tr>
              <td>{{plan.nickname}}</td>
              <td>{{plan.recurring.interval}}</td>
              <td>{{formatUnixDate plan.created}}</td>
              <td>{{plan.metadata.group_name}}</td>
              <td>{{plan.active}}</td>
              <td class="td-right">
                {{formatCurrency plan.currency plan.amountDollars}}
              </td>
              <td class="td-right">
                <LinkTo
                  class="btn no-text btn-icon"
                  @models={{array @controller.model.product.id plan.id}}
                  @route="adminPlugins.show.discourse-subscriptions-products.show.plans.show"
                >
                  {{dIcon "far-pen-to-square"}}
                </LinkTo>
              </td>
            </tr>
          {{else}}
            <tr>
              <td colspan="8">
                <hr />
                {{i18n
                  "discourse_subscriptions.admin.products.product.plan_help"
                }}
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    </p>
  {{/unless}}

  <div class="pull-right">
    <DButton
      @action={{@controller.cancelProduct}}
      @icon="xmark"
      @label="cancel"
    />

    {{#if @controller.model.product.isNew}}
      <DButton
        class="btn btn-primary"
        @action={{@controller.createProduct}}
        @icon="plus"
        @label="discourse_subscriptions.admin.products.operations.create"
      />
    {{else}}
      <DButton
        class="btn btn-primary"
        @action={{@controller.updateProduct}}
        @icon="check"
        @label="discourse_subscriptions.admin.products.operations.update"
      />
    {{/if}}
  </div>

  {{outlet}}
</template>
