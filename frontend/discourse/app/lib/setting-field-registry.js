import BoolControl from "discourse/components/setting-field/bool";
import CategoryListControl from "discourse/components/setting-field/category-list";
import CompactListControl from "discourse/components/setting-field/compact-list";
import DurationControl from "discourse/components/setting-field/duration";
import EnumControl from "discourse/components/setting-field/enum";
import GroupListControl from "discourse/components/setting-field/group-list";
import IntegerControl from "discourse/components/setting-field/integer";
import StringControl from "discourse/components/setting-field/string";

const REGISTRY = {};

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

registerSettingFieldType("bool", {
  type: "checkbox",
  format: "full",
  includeDescription: false,
  renderer: BoolControl,
});

registerSettingFieldType("integer", {
  type: "input-number",
  format: "full",
  renderer: IntegerControl,
});

registerSettingFieldType("enum", {
  type: "select",
  format: "large",
  labelFormat: "full",
  renderer: EnumControl,
});

registerSettingFieldType("group_list", {
  type: "custom",
  format: "large",
  labelFormat: "full",
  renderer: GroupListControl,
});

registerSettingFieldType("category_list", {
  type: "custom",
  format: "large",
  labelFormat: "full",
  renderer: CategoryListControl,
});

registerSettingFieldType("compact_list", {
  type: "custom",
  format: "large",
  labelFormat: "full",
  renderer: CompactListControl,
});

registerSettingFieldType("duration", {
  type: "custom",
  format: "full",
  renderer: DurationControl,
});

registerSettingFieldType("default", {
  type: "input",
  format: "large",
  labelFormat: "full",
  renderer: StringControl,
});
