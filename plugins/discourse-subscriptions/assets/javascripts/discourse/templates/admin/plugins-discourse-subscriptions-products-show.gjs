import { Input, Textarea } from "@ember/component";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import formatCurrency from "../../helpers/format-currency";
import formatUnixDate from "../../helpers/format-unix-date";

export default RouteTemplate(
  <template>
    <h4>{{i18n "discourse_subscriptions.admin.products.title"}}</h4>

    <form class="form-horizontal">
      <p>
        <label for="name">
          {{i18n "discourse_subscriptions.admin.products.product.name"}}
        </label>
        <Input
          @type="text"
          name="name"
          @value={{@controller.model.product.name}}
        />
      </p>

      <p>
        <label for="description">
          {{i18n "discourse_subscriptions.admin.products.product.description"}}
        </label>

        <Textarea
          name="description"
          @value={{@controller.model.product.metadata.description}}
          class="discourse-subscriptions-admin-textarea"
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
          @type="text"
          name="statement_descriptor"
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
          {{i18n
            "discourse_subscriptions.admin.products.product.repurchaseable"
          }}
        </label>

        <Input
          @type="checkbox"
          name="repurchaseable"
          @checked={{@controller.model.product.metadata.repurchaseable}}
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
          @type="checkbox"
          name="active"
          @checked={{@controller.model.product.active}}
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
            <th>{{i18n
                "discourse_subscriptions.admin.plans.plan.nickname"
              }}</th>
            <th>{{i18n
                "discourse_subscriptions.admin.plans.plan.interval"
              }}</th>
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
                @route="adminPlugins.discourse-subscriptions.products.show.plans.show"
                @models={{array @controller.model.product.id "new"}}
                class="btn"
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
                    @route="adminPlugins.discourse-subscriptions.products.show.plans.show"
                    @models={{array @controller.model.product.id plan.id}}
                    class="btn no-text btn-icon"
                  >
                    {{icon "far-pen-to-square"}}
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
        @label="cancel"
        @action={{@controller.cancelProduct}}
        @icon="xmark"
      />

      {{#if @controller.model.product.isNew}}
        <DButton
          @label="discourse_subscriptions.admin.products.operations.create"
          @action={{@controller.createProduct}}
          @icon="plus"
          class="btn btn-primary"
        />
      {{else}}
        <DButton
          @label="discourse_subscriptions.admin.products.operations.update"
          @action={{@controller.updateProduct}}
          @icon="check"
          class="btn btn-primary"
        />
      {{/if}}
    </div>

    {{outlet}}
  </template>
);
