import SchemaThemeSettingNumberField from "admin/components/schema-theme-setting/number-field";

export default class SchemaThemeSettingTypeFloat extends SchemaThemeSettingNumberField {
  step = 0.1;

  parseValue(value) {
    return parseFloat(value);
  }
}
