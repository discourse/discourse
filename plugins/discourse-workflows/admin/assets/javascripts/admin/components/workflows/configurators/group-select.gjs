import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import ComboBoxField, { DynamicOptionsComboBox } from "./combo-box";
import ExpressionWrapper from "./expression-wrapper";

export default class GroupSelect extends ComboBoxField {
  @service router;

  get clearable() {
    return !this.args.schema?.required;
  }

  @action
  manageGroups() {
    this.router.transitionTo("groups");
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      <div class="workflows-property-engine__select-with-action">
        <DynamicOptionsComboBox
          @content={{this.options}}
          @loadOptions={{if this.usesRemoteOptions this.loadRemoteOptions}}
          @nameProperty="name"
          @value={{@field.value}}
          @valueProperty="id"
          @onChange={{this.handleChange}}
          @options={{hash
            filterable=this.filterable
            none=this.none
            castInteger=this.castInteger
            clearable=this.clearable
          }}
        />
        {{#unless @field.value}}
          <DButton
            @action={{this.manageGroups}}
            @label="discourse_workflows.group.manage_groups"
            @icon="plus"
            class="btn-default"
          />
        {{/unless}}
      </div>
    </ExpressionWrapper>
  </template>
}
