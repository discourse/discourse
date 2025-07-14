import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <h4>{{i18n "discourse_subscriptions.admin.plans.title"}}</h4>

    <form class="form-horizontal">
      <p>
        <label for="product">
          {{i18n "discourse_subscriptions.admin.products.product.name"}}
        </label>

        <Input
          @type="text"
          name="product_name"
          @value={{@controller.model.product.name}}
          disabled={{true}}
        />
      </p>

      <p>
        <label for="name">
          {{i18n "discourse_subscriptions.admin.plans.plan.nickname"}}
        </label>

        <Input
          @type="text"
          name="name"
          @value={{@controller.model.plan.nickname}}
        />

        <div class="control-instructions">
          {{i18n "discourse_subscriptions.admin.plans.plan.nickname_help"}}
        </div>
      </p>

      <p>
        <label for="interval">
          {{i18n "discourse_subscriptions.admin.plans.plan.group"}}
        </label>

        <ComboBox
          @valueProperty="name"
          @content={{@controller.availableGroups}}
          @value={{@controller.selectedGroup}}
          @onChange={{fn (mut @controller.model.plan.metadata.group_name)}}
        />

        <div class="control-instructions">
          {{i18n "discourse_subscriptions.admin.plans.plan.group_help"}}
        </div>
      </p>

      <p>
        <label for="amount">
          {{i18n "discourse_subscriptions.admin.plans.plan.amount"}}
        </label>

        {{#if @controller.planFieldDisabled}}
          <Input
            class="plan-amount plan-currency"
            disabled={{true}}
            @value={{@controller.model.plan.currency}}
          />
        {{else}}
          <ComboBox
            @disabled={{@controller.planFieldDisabled}}
            @content={{@controller.currencies}}
            @value={{@controller.model.plan.currency}}
            @onChange={{fn (mut @controller.model.plan.currency)}}
          />
        {{/if}}

        <Input
          class="plan-amount"
          @type="text"
          name="name"
          @value={{@controller.model.plan.amountDollars}}
          disabled={{@controller.planFieldDisabled}}
        />
      </p>

      <p>
        <label for="recurring">
          {{i18n "discourse_subscriptions.admin.plans.plan.recurring"}}
        </label>

        {{#if @controller.planFieldDisabled}}
          <Input
            @type="checkbox"
            name="recurring"
            @checked={{@controller.model.plan.isRecurring}}
            disabled={{true}}
          />
        {{else}}
          <Input
            @type="checkbox"
            name="recurring"
            @checked={{@controller.model.plan.isRecurring}}
            {{on "change" @controller.changeRecurring}}
          />
        {{/if}}
      </p>

      {{#if @controller.model.plan.isRecurring}}
        <p>
          <label for="interval">
            {{i18n "discourse_subscriptions.admin.plans.plan.interval"}}
          </label>

          {{#if @controller.planFieldDisabled}}
            <Input disabled={{true}} @value={{@controller.selectedInterval}} />
          {{else}}
            <ComboBox
              @valueProperty="name"
              @content={{@controller.availableIntervals}}
              @value={{@controller.selectedInterval}}
              @onChange={{fn (mut @controller.selectedInterval)}}
            />
          {{/if}}
        </p>

        <p>
          <label for="trial">
            {{i18n "discourse_subscriptions.admin.plans.plan.trial"}}
            ({{i18n "discourse_subscriptions.optional"}})
          </label>

          <Input
            @type="text"
            name="trial"
            @value={{@controller.model.plan.trial_period_days}}
          />

          <div class="control-instructions">
            {{i18n "discourse_subscriptions.admin.plans.plan.trial_help"}}
          </div>
        </p>
      {{/if}}

      <p>
        <label for="active">
          {{i18n "discourse_subscriptions.admin.plans.plan.active"}}
        </label>
        <Input
          @type="checkbox"
          name="active"
          @checked={{@controller.model.plan.active}}
        />
      </p>
    </form>

    <section>
      <hr />

      <p class="control-instructions">
        {{i18n "discourse_subscriptions.admin.plans.operations.create_help"}}
      </p>

      <div class="pull-right">
        {{#if @controller.model.plan.isNew}}
          <DButton
            @label="discourse_subscriptions.admin.plans.operations.create"
            @action={{@controller.createPlan}}
            @icon="plus"
            class="btn btn-primary"
          />
        {{else}}
          <DButton
            @label="discourse_subscriptions.admin.plans.operations.update"
            @action={{@controller.updatePlan}}
            @icon="check"
            class="btn btn-primary"
          />
        {{/if}}
      </div>
    </section>
  </template>
);
