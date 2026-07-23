import BoolControl from "discourse/components/setting-field/bool";
import CategoryListControl from "discourse/components/setting-field/category-list";
import CompactListControl from "discourse/components/setting-field/compact-list";
import DurationControl from "discourse/components/setting-field/duration";
import EnumControl from "discourse/components/setting-field/enum";
import GroupListControl from "discourse/components/setting-field/group-list";
import IntegerControl from "discourse/components/setting-field/integer";
import RadioGroupControl from "discourse/components/setting-field/radio-group";

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

registerSettingFieldType("default", { ...ROW, type: "input" });
registerSettingFieldType("textarea", { ...ROW, type: "textarea" });
registerSettingFieldType("email", { ...ROW, type: "input-email" });
registerSettingFieldType("date", { ...ROW, type: "input-date" });
registerSettingFieldType("password", { ...ROW, type: "password" });
registerSettingFieldType("radio-group", {
  ...ROW,
  type: "radio-group",
  renderer: RadioGroupControl,
});
registerSettingFieldType("enum", {
  ...ROW,
  type: "select",
  renderer: EnumControl,
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
