import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import {
  fieldType,
  formatOptionValue,
  normalizeOptions,
  propertyOptionLabel,
  propertySelectNoneKey,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

function optionValue(option, valueProperty) {
  return option[valueProperty] ?? option.id ?? option.value;
}

function optionName(option, nameProperty) {
  return option[nameProperty] ?? option.name ?? option.label;
}

export default class ComboBoxField extends Component {
  @service workflowsNodeTypes;

  @tracked _remoteOptions = null;

  constructor(owner, args) {
    super(owner, args);
    const source = args.schema?.options_source;
    const identifier = args.nodeDefinition?.identifier;
    if (source && identifier) {
      this.workflowsNodeTypes
        .loadSourceOptions(identifier, source)
        .then((options) => {
          this._remoteOptions = options;
        });
    }
  }

  get metadataOptions() {
    const source = this.args.schema?.options_source;
    if (!source) {
      return null;
    }
    return this._remoteOptions || [];
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

  get filterable() {
    return Boolean(this.controlOptions.filterable);
  }

  get valueProperty() {
    return this.controlOptions.value_property || "id";
  }

  get nameProperty() {
    return this.controlOptions.name_property || "name";
  }

  get patchFromOption() {
    return this.controlOptions.patch_from_option || {};
  }

  get resets() {
    return this.controlOptions.resets || [];
  }

  get castInteger() {
    return fieldType(this.args.schema) === "integer";
  }

  get options() {
    if (this.metadataOptions) {
      return this.metadataOptions.map((option) => ({
        id: optionValue(option, this.valueProperty),
        name:
          optionName(option, this.nameProperty) ||
          optionValue(option, this.valueProperty),
        original: option,
      }));
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

  @action
  handleChange(value) {
    this.args.field.set(value);

    const selectedOption = this.options.find(
      (option) => String(option.id) === String(value)
    );

    for (const [fieldName, propertyName] of Object.entries(
      this.patchFromOption
    )) {
      this.args.formApi?.set(
        fieldName,
        selectedOption?.original?.[propertyName] || ""
      );
    }

    const schema = this.args.nodeDefinition?.property_schema || {};
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

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      <ComboBox
        @content={{this.options}}
        @nameProperty="name"
        @value={{@field.value}}
        @valueProperty="id"
        @onChange={{this.handleChange}}
        @options={{hash
          filterable=this.filterable
          none=this.none
          castInteger=this.castInteger
        }}
      />
    </ExpressionWrapper>
  </template>
}
