import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DButton from "discourse/ui-kit/d-button";
import ComboBoxField, { DynamicOptionsComboBox } from "./combo-box";
import ExpressionWrapper from "./expression-wrapper";

export class DynamicOptionsGroupChooser extends GroupChooser {
  search(filter) {
    if (this.loadOptions) {
      return Promise.resolve(this.loadOptions(filter)).then((options) => {
        const selectedValues = new Set(
          makeArray(this.selectedContent).map((item) =>
            String(this.getValue(item))
          )
        );

        return options.filter(
          (option) => !selectedValues.has(String(this.getValue(option)))
        );
      });
    }

    return super.search(filter);
  }
}

function groupValuesFromValue(value) {
  return Array.isArray(value) ? value : [];
}

export default class GroupSelect extends ComboBoxField {
  @service router;

  @tracked selectedOptions = [];

  get multiple() {
    return Boolean(this.args.schema?.ui?.multiple);
  }

  get clearable() {
    return !this.args.schema?.required;
  }

  get hasValue() {
    if (this.multiple) {
      return this.value.length > 0;
    }

    const value = this.args.field.value;
    return value !== null && value !== undefined && value !== "";
  }

  get value() {
    return this.multiple
      ? groupValuesFromValue(this.args.field.value)
      : this.args.field.value;
  }

  get contentOptions() {
    if (!this.usesRemoteOptions) {
      return this.options;
    }

    const optionsByValue = new Map(
      [
        ...this.formatOptions(this.metadataOptions || []),
        ...this.selectedOptions,
      ].map((option) => [String(option.id), option])
    );

    return this.value.map(
      (value) => optionsByValue.get(String(value)) || { id: value, name: value }
    );
  }

  @action
  manageGroups() {
    this.router.transitionTo("groups");
  }

  @action
  handleMultiChange(value, selectedOptions) {
    this.selectedOptions = makeArray(selectedOptions);
    this.args.field.set(value || []);
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      <div class="workflows-property-engine__select-with-action">
        {{#if this.multiple}}
          <DynamicOptionsGroupChooser
            @content={{this.contentOptions}}
            @loadOptions={{if this.usesRemoteOptions this.loadRemoteOptions}}
            @nameProperty="name"
            @value={{this.value}}
            @valueProperty="id"
            @onChange={{this.handleMultiChange}}
            @options={{hash filterable=this.filterable none=this.none}}
          />
        {{else}}
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
        {{/if}}
        {{#unless this.hasValue}}
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
