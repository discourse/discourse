import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  fieldType,
  formatOptionValue,
  normalizeOptions,
  propertyOptionLabel,
  propertySelectNoneKey,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

export class DynamicOptionsComboBox extends ComboBox {
  search(filter) {
    if (this.loadOptions) {
      return this.loadOptions(filter);
    }

    return super.search(filter);
  }
}

function optionValue(option, valueProperty) {
  return option[valueProperty] ?? option.id ?? option.value;
}

function optionName(option, nameProperty) {
  return option[nameProperty] ?? option.name ?? option.label;
}

function hasValue(value) {
  return value !== null && value !== undefined && value !== "";
}

function usesFieldValue(model) {
  return model?.source === "field_value";
}

// Keep a stable reference for didUpdate dependencies when remote options are used.
const EMPTY_METADATA_OPTIONS = Object.freeze([]);

export default class ComboBoxField extends Component {
  @service router;
  @service workflowsNodeTypes;

  get methodName() {
    return this.args.schema?.type_options?.load_options_method;
  }

  get identifier() {
    return (
      this.args.nodeDefinition?.name || this.args.nodeDefinition?.identifier
    );
  }

  get typeVersion() {
    return this.args.nodeDefinition?.version || this.args.node?.typeVersion;
  }

  get localOptions() {
    return (
      this.args.metadata?.[this.methodName] ||
      this.args.nodeDefinition?.metadata?.[this.methodName]
    );
  }

  get hasLoadOptionsDependencies() {
    const dependencies =
      this.args.schema?.type_options?.load_options_depends_on;

    return Array.isArray(dependencies)
      ? dependencies.length > 0
      : Boolean(dependencies);
  }

  get usesRemoteOptions() {
    return Boolean(
      this.methodName &&
      this.identifier &&
      (!this.localOptions || this.hasLoadOptionsDependencies)
    );
  }

  get metadataOptions() {
    if (!this.methodName) {
      return null;
    }
    if (this.localOptions) {
      return this.localOptions;
    }
    return EMPTY_METADATA_OPTIONS;
  }

  get controlOptions() {
    return this.args.schema?.control_options || {};
  }

  get none() {
    return (
      this.controlOptions.none ||
      propertySelectNoneKey(this.args.nodeDefinition, this.args.fieldName)
    );
  }

  get translatedNone() {
    const labelField = this.controlOptions.none_label_field;
    const labelKey = this.controlOptions.none_label_i18n_key;

    if (!labelField || !labelKey) {
      return null;
    }

    const value =
      (this.args.nodeParameters || this.args.configuration || {})[labelField] ||
      null;

    return value ? i18n(labelKey, { value }) : null;
  }

  get filterable() {
    return Boolean(this.controlOptions.filterable);
  }

  get valueProperty() {
    return this.controlOptions.value_property || "id";
  }

  get nameProperty() {
    return this.controlOptions.name_property || "name";
  }

  get setFromOption() {
    return this.controlOptions.set_from_option || {};
  }

  get resets() {
    return this.controlOptions.resets || [];
  }

  get castInteger() {
    return fieldType(this.args.schema) === "integer";
  }

  get actionRoute() {
    return this.controlOptions.action_route;
  }

  get actionRouteModels() {
    const models = this.controlOptions.action_route_models;

    if (!models) {
      return [];
    }

    return (Array.isArray(models) ? models : [models]).map((model) =>
      usesFieldValue(model) ? this.args.field.value : model
    );
  }

  get actionIcon() {
    return this.controlOptions.action_icon || "plus";
  }

  get actionLabel() {
    return this.controlOptions.action_label;
  }

  get actionRequiresValue() {
    const models = this.controlOptions.action_route_models;

    return (Array.isArray(models) ? models : [models]).some(usesFieldValue);
  }

  get showActionButton() {
    return (
      this.actionRoute &&
      (!this.actionRequiresValue || hasValue(this.args.field.value))
    );
  }

  get options() {
    if (this.metadataOptions) {
      return this.formatOptions(this.metadataOptions);
    }

    const optionFormat = this.controlOptions.option_format;
    return normalizeOptions(this.args.schema.options).map((option) => ({
      id: option.value,
      name: optionFormat
        ? formatOptionValue(option.value, optionFormat)
        : propertyOptionLabel(
            this.args.nodeDefinition,
            this.args.fieldName,
            option
          ),
      original: option,
    }));
  }

  formatOptions(options) {
    return options.map((option) => ({
      id: optionValue(option, this.valueProperty),
      name:
        optionName(option, this.nameProperty) ||
        optionValue(option, this.valueProperty),
      original: option,
    }));
  }

  selectedOption(value = this.args.field.value) {
    if (!hasValue(value)) {
      return null;
    }

    return (
      this.options.find((option) => String(option.id) === String(value)) || null
    );
  }

  setOptionDerivedFields(selectedOption) {
    if (!this.args.formApi || Object.keys(this.setFromOption).length === 0) {
      return;
    }

    for (const [fieldName, propertyName] of Object.entries(
      this.setFromOption
    )) {
      const selectedOptionValue = selectedOption
        ? (selectedOption.original?.[propertyName] ??
          selectedOption[propertyName] ??
          "")
        : "";

      if (this.args.formApi.get(fieldName) !== selectedOptionValue) {
        this.args.formApi.set(fieldName, selectedOptionValue);
      }
    }
  }

  @action
  syncOptionDerivedFields() {
    const selectedOption = this.selectedOption();
    if (selectedOption) {
      this.setOptionDerivedFields(selectedOption);
    }
  }

  remoteOptionsContext(filter = null) {
    const context = {
      path: this.args.fieldName,
      currentNodeParameters:
        this.args.nodeParameters || this.args.configuration || {},
      credentials: this.args.credentials || {},
      node: this.args.node,
      filter,
    };

    return this.args.session?.nodeParameterOptionsContext(context) || context;
  }

  @action
  async loadRemoteOptions(filter = null) {
    if (!this.usesRemoteOptions) {
      return null;
    }

    const options = await this.workflowsNodeTypes.loadNodeParameterOptions(
      this.identifier,
      this.methodName,
      this.typeVersion,
      this.remoteOptionsContext(filter)
    );

    return this.formatOptions(options);
  }

  @action
  handleChange(value, selectedItem = null) {
    this.args.field.set(value);

    const selectedOption = selectedItem || this.selectedOption(value);

    this.setOptionDerivedFields(selectedOption);

    const schema = this.args.nodeDefinition?.properties || {};
    for (const fieldName of this.resets) {
      const type = fieldType(schema[fieldName]);
      let resetValue = null;
      if (type === "array" || type === "collection") {
        resetValue = [];
      } else if (type === "object") {
        resetValue = {};
      }
      this.args.formApi?.set(fieldName, resetValue);
    }
  }

  @action
  performAction() {
    if (!this.showActionButton) {
      return;
    }

    this.router.transitionTo(this.actionRoute, ...this.actionRouteModels);
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
      <span
        hidden
        {{didInsert this.syncOptionDerivedFields}}
        {{didUpdate
          this.syncOptionDerivedFields
          @field.value
          this.metadataOptions
        }}
      ></span>
      {{#if this.showActionButton}}
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
              translatedNone=this.translatedNone
              castInteger=this.castInteger
            }}
          />
          <DButton
            @action={{this.performAction}}
            @label={{this.actionLabel}}
            @icon={{this.actionIcon}}
            class="btn-default"
          />
        </div>
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
            translatedNone=this.translatedNone
            castInteger=this.castInteger
          }}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
