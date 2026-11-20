import ColorListControl from "discourse/admin/components/setting-field/color-list";
import EmojiListControl from "discourse/admin/components/setting-field/emoji-list";
import FileSizeRestrictionControl from "discourse/admin/components/setting-field/file-size-restriction";
import FileTypesListControl from "discourse/admin/components/setting-field/file-types-list";
import SecretListControl from "discourse/admin/components/setting-field/secret-list";
import SimpleListControl from "discourse/admin/components/setting-field/simple-list";
import UploadControl from "discourse/admin/components/setting-field/upload";
import UploadedImageListControl from "discourse/admin/components/setting-field/uploaded-image-list";
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
  color_list: ColorListControl,
  emoji_list: EmojiListControl,
  secret_list: SecretListControl,
  upload: UploadControl,
  file_size_restriction: FileSizeRestrictionControl,
  file_types_list: FileTypesListControl,
  uploaded_image_list: UploadedImageListControl,
};

for (const [type, renderer] of Object.entries(RENDERERS)) {
  registerSettingFieldType(type, { ...CUSTOM_CONTROL, renderer });
}
