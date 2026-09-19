import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

const DEFAULT_AMOUNT = 30;
const DEFAULT_UNIT = "days";
const UNIT_OPTIONS = ["hours", "days", "weeks", "months"].map((unit) => ({
  value: unit,
  label: i18n(`discourse_workflows.user_seen.not_seen_for_unit_${unit}`),
}));

function isBlank(value) {
  return value === undefined || value === null || value === "";
}

export default class UserSeenTriggerOptions extends Component {
  unitOptions = UNIT_OPTIONS;

  get notSeenForMoreThanEnabled() {
    return this.args.configuration?.trigger_on_not_seen_for_more_than === true;
  }

  @action
  handleNotSeenForMoreThanSet(value, { set }) {
    set("trigger_on_not_seen_for_more_than", value);

    if (!value) {
      return;
    }

    if (isBlank(this.args.formApi?.get("not_seen_for_amount"))) {
      set("not_seen_for_amount", DEFAULT_AMOUNT);
    }

    if (isBlank(this.args.formApi?.get("not_seen_for_unit"))) {
      set("not_seen_for_unit", DEFAULT_UNIT);
    }
  }

  <template>
    <@form.Field
      @format="full"
      @name="trigger_on_first_seen"
      @title={{i18n "discourse_workflows.user_seen.trigger_on_first_seen"}}
      @type="checkbox"
      as |field|
    >
      <field.Control>
        {{i18n
          "discourse_workflows.user_seen.trigger_on_first_seen_description"
        }}
      </field.Control>
    </@form.Field>

    <@form.Field
      @format="full"
      @name="trigger_on_not_seen_for_more_than"
      @onSet={{this.handleNotSeenForMoreThanSet}}
      @title={{i18n
        "discourse_workflows.user_seen.trigger_on_not_seen_for_more_than"
      }}
      @type="checkbox"
      as |field|
    >
      <field.Control>
        {{i18n
          "discourse_workflows.user_seen.trigger_on_not_seen_for_more_than_description"
        }}
      </field.Control>
    </@form.Field>

    {{#if this.notSeenForMoreThanEnabled}}
      <@form.Container class="workflows-user-seen-duration">
        <@form.Field
          class="workflows-user-seen-duration__amount"
          @name="not_seen_for_amount"
          @showTitle={{false}}
          @title={{i18n "discourse_workflows.user_seen.not_seen_for_amount"}}
          @type="input-number"
          @validation="required|integer|between:1,9007199254740991"
          as |field|
        >
          <field.Control />
        </@form.Field>

        <@form.Field
          class="workflows-user-seen-duration__unit"
          @name="not_seen_for_unit"
          @showTitle={{false}}
          @title={{i18n "discourse_workflows.user_seen.not_seen_for_unit"}}
          @type="select"
          @validation="required"
          as |field|
        >
          <field.Control @includeNone={{false}} as |select|>
            {{#each this.unitOptions as |option|}}
              <select.Option @value={{option.value}}>
                {{option.label}}
              </select.Option>
            {{/each}}
          </field.Control>
        </@form.Field>
      </@form.Container>
    {{/if}}
  </template>
}
