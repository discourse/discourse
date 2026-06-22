export default function settingToDefinition(setting) {
  return {
    key: setting.setting,
    label: setting.humanized_name,
    description: setting.description,
    type: setting.type,
    list_type: setting.list_type,
    min: setting.min,
    max: setting.max,
    choices: setting.choices,
    valid_values: setting.valid_values,
  };
}
