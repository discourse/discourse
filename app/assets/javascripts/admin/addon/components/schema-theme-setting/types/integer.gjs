import SchemaThemeSettingNumberField from "admin/components/schema-theme-setting/number-field";

export default class SchemaThemeSettingTypeInteger extends SchemaThemeSettingNumberField {
  inputMode = "numeric";
  pattern = "[0-9]*";

  parseValue(value) {
    return parseInt(value, 10);
  }
}
