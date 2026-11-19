import EmojiListControl from "discourse/admin/components/setting-field/emoji-list";
import SecretListControl from "discourse/admin/components/setting-field/secret-list";
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

const RENDERERS = {
  simple_list: SimpleListControl,
  emoji_list: EmojiListControl,
  secret_list: SecretListControl,
};

for (const [type, renderer] of Object.entries(RENDERERS)) {
  registerSettingFieldType(type, { ...CUSTOM_CONTROL, renderer });
}
