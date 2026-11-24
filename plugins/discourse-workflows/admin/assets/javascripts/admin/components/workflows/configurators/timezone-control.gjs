import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import TimezoneInput from "discourse/select-kit/components/timezone-input";
import DSelectTimezone from "discourse/ui-kit/select/recipes/timezones/d-select-timezone";
import { i18n } from "discourse-i18n";
import { propertySelectNoneKey } from "../../../lib/workflows/property-engine.js";
import ExpressionWrapper from "./expression-wrapper.gjs";

export default class TimezoneControl extends Component {
  @service siteSettings;

  get none() {
    return (
      this.args.schema?.control_options?.none ||
      propertySelectNoneKey(this.args.nodeDefinition, this.args.fieldName)
    );
  }

  get clearable() {
    return !this.args.schema?.required;
  }

  /** The held zone; an empty string means none was chosen. */
  get value() {
    return this.args.field.value || null;
  }

  <template>
    <ExpressionWrapper
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectTimezone
          @describedBy={{@field.describedBy}}
          @disabled={{@field.disabled}}
          @id={{@field.id}}
          @invalid={{if @field.error true false}}
          @noneOption={{this.clearable}}
          @onChange={{@field.set}}
          @texts={{hash ariaLabel=@field.title noneLabel=(i18n this.none)}}
          @value={{this.value}}
        />
      {{else}}
        <TimezoneInput
          @onChange={{@field.set}}
          @options={{hash none=this.none clearable=this.clearable}}
          @value={{@field.value}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
