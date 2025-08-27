import SchemaSettingNumberField from "admin/components/schema-setting/number-field";

export default class SchemaSettingTypeInteger extends SchemaSettingNumberField {
  inputMode = "numeric";
  pattern = "[0-9]*";

  parseValue(value) {
    return parseInt(value, 10);
  }
}
