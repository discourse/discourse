import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  <h4>{{i18n "discourse_subscriptions.admin.plans.title"}}</h4>

  <form class="form-horizontal">
    <p>
      <label for="product">
        {{i18n "discourse_subscriptions.admin.products.product.name"}}
      </label>

      <input
        disabled
        name="product_name"
        type="text"
        value={{@controller.model.product.name}}
      />
    </p>

    <p>
      <label for="name">
        {{i18n "discourse_subscriptions.admin.plans.plan.nickname"}}
      </label>

      <input
        name="name"
        type="text"
        value={{@controller.model.plan.nickname}}
        {{on
          "input"
          (withEventValue (fn (mut @controller.model.plan.nickname)))
        }}
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
        @content={{@controller.availableGroups}}
        @onChange={{fn (mut @controller.model.plan.metadata.group_name)}}
        @value={{@controller.selectedGroup}}
        @valueProperty="name"
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
        <input
          class="plan-amount plan-currency"
          disabled
          type="text"
          value={{@controller.model.plan.currency}}
        />
      {{else}}
        <ComboBox
          @content={{@controller.currencies}}
          @disabled={{@controller.planFieldDisabled}}
          @onChange={{fn (mut @controller.model.plan.currency)}}
          @value={{@controller.model.plan.currency}}
        />
      {{/if}}

      <input
        class="plan-amount"
        disabled={{@controller.planFieldDisabled}}
        name="name"
        type="text"
        value={{@controller.model.plan.amountDollars}}
        {{on
          "input"
          (withEventValue (fn (mut @controller.model.plan.amountDollars)))
        }}
      />
    </p>

    <p>
      <label for="recurring">
        {{i18n "discourse_subscriptions.admin.plans.plan.recurring"}}
      </label>

      {{#if @controller.planFieldDisabled}}
        <Input
          disabled
          name="recurring"
          @checked={{@controller.model.plan.isRecurring}}
          @type="checkbox"
        />
      {{else}}
        <Input
          name="recurring"
          @checked={{@controller.model.plan.isRecurring}}
          @type="checkbox"
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
          <input disabled type="text" value={{@controller.selectedInterval}} />
        {{else}}
          <ComboBox
            @content={{@controller.availableIntervals}}
            @onChange={{fn (mut @controller.selectedInterval)}}
            @value={{@controller.selectedInterval}}
            @valueProperty="name"
          />
        {{/if}}
      </p>

      <p>
        <label for="trial">
          {{i18n "discourse_subscriptions.admin.plans.plan.trial"}}
          ({{i18n "discourse_subscriptions.optional"}})
        </label>

        <input
          name="trial"
          type="text"
          value={{@controller.model.plan.trial_period_days}}
          {{on
            "input"
            (withEventValue (fn (mut @controller.model.plan.trial_period_days)))
          }}
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
        name="active"
        @checked={{@controller.model.plan.active}}
        @type="checkbox"
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
          class="btn btn-primary"
          @action={{@controller.createPlan}}
          @icon="plus"
          @label="discourse_subscriptions.admin.plans.operations.create"
        />
      {{else}}
        <DButton
          class="btn btn-primary"
          @action={{@controller.updatePlan}}
          @icon="check"
          @label="discourse_subscriptions.admin.plans.operations.update"
        />
      {{/if}}
    </div>
  </section>
</template>
