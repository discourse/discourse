import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import ComboBox from "discourse/select-kit/components/combo-box";
import {
  normalizeOptions,
  propertyOptionLabel,
  propertySelectNoneKey,
} from "../../../lib/workflows/property-engine";

function optionValue(option, valueProperty) {
  return option[valueProperty] ?? option.id ?? option.value;
}

function optionName(option, nameProperty) {
  return option[nameProperty] ?? option.name ?? option.label;
}

export default class PropertyEngineComboBox extends Component {
  get metadataOptions() {
    const source = this.args.schema?.ui?.options_source;
    return source ? this.args.metadata?.[source] || [] : null;
  }

  get none() {
    return (
      this.args.schema?.ui?.none ||
      propertySelectNoneKey(this.args.nodeDefinition, this.args.fieldName)
    );
  }

  get filterable() {
    return Boolean(this.args.schema?.ui?.filterable);
  }

  get valueProperty() {
    return this.args.schema?.ui?.value_property || "id";
  }

  get nameProperty() {
    return this.args.schema?.ui?.name_property || "name";
  }

  get patchFromOption() {
    return this.args.schema?.ui?.patch_from_option || {};
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

    return normalizeOptions(this.args.schema.options).map((option) => ({
      id: option.value,
      name: propertyOptionLabel(
        this.args.nodeDefinition,
        this.args.fieldName,
        option
      ),
      original: option,
    }));
  }

  @action
  handleChange(value) {
    const selectedOption = this.options.find(
      (option) => String(option.id) === String(value)
    );
    const patch = { [this.args.fieldName]: value };

    Object.entries(this.patchFromOption).forEach(
      ([fieldName, propertyName]) => {
        patch[fieldName] = selectedOption?.original?.[propertyName] || "";
      }
    );

    this.args.onPatch?.(patch);
  }

  <template>
    <ComboBox
      @content={{this.options}}
      @nameProperty="name"
      @value={{@value}}
      @valueProperty="id"
      @onChange={{this.handleChange}}
      @options={{hash filterable=this.filterable none=this.none}}
    />
  </template>
}
