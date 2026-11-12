import BoolControl from "discourse/components/setting-field/bool";
import CategoryControl from "discourse/components/setting-field/category";
import CategoryListControl from "discourse/components/setting-field/category-list";
import CompactListControl from "discourse/components/setting-field/compact-list";
import DurationControl from "discourse/components/setting-field/duration";
import EnumControl from "discourse/components/setting-field/enum";
import GroupControl from "discourse/components/setting-field/group";
import GroupListControl from "discourse/components/setting-field/group-list";
import IconControl from "discourse/components/setting-field/icon";
import IntegerControl from "discourse/components/setting-field/integer";
import LocaleEnumControl from "discourse/components/setting-field/locale-enum";
import RadioGroupControl from "discourse/components/setting-field/radio-group";
import TagGroupListControl from "discourse/components/setting-field/tag-group-list";
import TagListControl from "discourse/components/setting-field/tag-list";

const REGISTRY = {};

const ROW = { format: "large", labelFormat: "full" };
const INLINE = { format: "full" };

export function registerSettingFieldType(type, entry) {
  REGISTRY[type] = entry;
}

export function resolveSettingFieldType(definition) {
  return REGISTRY[typeKeyFor(definition)] ?? REGISTRY.default;
}

export function settingFieldValidation(definition) {
  const rules = [];

  if (definition.required) {
    rules.push("required");
  }

  if (definition.type === "integer") {
    rules.push("number");
  }

  return rules.length > 0 ? rules.join("|") : undefined;
}

function typeKeyFor({ type, subtype, list_type }) {
  if (subtype && REGISTRY[subtype]) {
    return subtype;
  }

  let resolved = type;
  if (type === "list" && list_type) {
    resolved = `${list_type}_list`;
  }

  if (resolved && REGISTRY[resolved]) {
    return resolved;
  }

  return "default";
}

const TEXT_INPUT = { ...ROW, type: "input", adminReady: true };
const CUSTOM_CONTROL = { ...ROW, type: "custom", adminReady: true };

registerSettingFieldType("default", { ...ROW, type: "input" });
registerSettingFieldType("string", TEXT_INPUT);
registerSettingFieldType("float", TEXT_INPUT);
registerSettingFieldType("username", TEXT_INPUT);
registerSettingFieldType("textarea", {
  ...ROW,
  type: "textarea",
  adminReady: true,
});
registerSettingFieldType("email", {
  ...ROW,
  type: "input-email",
  adminReady: true,
});
registerSettingFieldType("date", { ...ROW, type: "input-date" });
registerSettingFieldType("password", {
  ...ROW,
  type: "password",
  adminReady: true,
});
registerSettingFieldType("radio-group", {
  ...ROW,
  type: "radio-group",
  renderer: RadioGroupControl,
});
registerSettingFieldType("enum", {
  ...ROW,
  type: "select",
  adminReady: true,
  renderer: EnumControl,
});
registerSettingFieldType("locale_enum", {
  ...ROW,
  type: "select",
  adminReady: true,
  renderer: LocaleEnumControl,
});
registerSettingFieldType("icon", {
  ...ROW,
  type: "icon",
  adminReady: true,
  renderer: IconControl,
});
registerSettingFieldType("category", {
  ...CUSTOM_CONTROL,
  renderer: CategoryControl,
});
registerSettingFieldType("group", {
  ...CUSTOM_CONTROL,
  renderer: GroupControl,
});
registerSettingFieldType("tag_list", {
  ...CUSTOM_CONTROL,
  renderer: TagListControl,
});
registerSettingFieldType("tag_group_list", {
  ...CUSTOM_CONTROL,
  renderer: TagGroupListControl,
});
registerSettingFieldType("group_list", {
  ...ROW,
  type: "custom",
  renderer: GroupListControl,
});
registerSettingFieldType("category_list", {
  ...ROW,
  type: "custom",
  renderer: CategoryListControl,
});
registerSettingFieldType("compact_list", {
  ...ROW,
  type: "custom",
  renderer: CompactListControl,
});
registerSettingFieldType("bool", {
  ...INLINE,
  type: "checkbox",
  includeDescription: false,
  adminReady: true,
  renderer: BoolControl,
});
registerSettingFieldType("integer", {
  ...INLINE,
  type: "input-number",
  adminReady: true,
  renderer: IntegerControl,
});
registerSettingFieldType("duration", {
  ...INLINE,
  type: "custom",
  renderer: DurationControl,
});
