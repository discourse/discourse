import SimpleListControl from "discourse/admin/components/setting-field/simple-list";
import ValueListControl, {
  VARIANTS as VALUE_LIST_VARIANTS,
} from "discourse/admin/components/setting-field/value-list";
import {
  CUSTOM_CONTROL,
  registerSettingFieldType,
} from "discourse/lib/setting-field-registry";

for (const type of Object.keys(VALUE_LIST_VARIANTS)) {
  registerSettingFieldType(type, {
    ...CUSTOM_CONTROL,
    renderer: ValueListControl,
  });
}

registerSettingFieldType("simple_list", {
  ...CUSTOM_CONTROL,
  renderer: SimpleListControl,
});
