import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import MultiSelect from "discourse/select-kit/components/multi-select";
import {
  formatOptionValue,
  normalizeOptions,
  propertyOptionLabel,
  propertySelectNoneKey,
} from "../../../lib/workflows/property-engine";
import ExpressionWrapper from "./expression-wrapper";

export class DynamicOptionsMultiSelect extends MultiSelect {
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

function optionValue(option, valueProperty) {
  return option[valueProperty] ?? option.id ?? option.value;
}

function optionName(option, nameProperty) {
  return option[nameProperty] ?? option.name ?? option.label;
}

export default class MultiComboBox extends Component {
  @service workflowsNodeTypes;

  @tracked selectedOptions = [];

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
    return [];
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

  formatOptions(options) {
    return options.map((option) => ({
      id: optionValue(option, this.valueProperty),
      name:
        optionName(option, this.nameProperty) ||
        optionValue(option, this.valueProperty),
      original: option,
    }));
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

  get value() {
    const val = this.args.field.value;
    return Array.isArray(val) ? val : [];
  }

  @action
  handleChange(value, selectedOptions) {
    this.selectedOptions = makeArray(selectedOptions);
    this.args.field.set(value);
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
      <DynamicOptionsMultiSelect
        @content={{this.contentOptions}}
        @loadOptions={{if this.usesRemoteOptions this.loadRemoteOptions}}
        @value={{this.value}}
        @nameProperty="name"
        @valueProperty="id"
        @onChange={{this.handleChange}}
        @options={{hash filterable=this.filterable none=this.none}}
      />
    </ExpressionWrapper>
  </template>
}
