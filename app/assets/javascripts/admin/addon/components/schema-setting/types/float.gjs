import SchemaSettingNumberField from "admin/components/schema-setting/number-field";

export default class SchemaSettingTypeFloat extends SchemaSettingNumberField {
  step = 0.1;

  parseValue(value) {
    return parseFloat(value);
  }
}
