export function getValueType(value) {
  if (value === null || value === undefined) {
    return "null";
  }
  if (typeof value === "object" && value._type === "param" && value._data) {
    return "param";
  }
  if (Array.isArray(value)) {
    return "array";
  }
  if (typeof value === "object") {
    return "object";
  }
  if (typeof value === "boolean") {
    return value ? "boolean-true" : "boolean-false";
  }
  return typeof value;
}

export function getTypeIcon(type) {
  const iconMap = {
    string: "lucide-type",
    number: "lucide-hash",
    "boolean-true": "lucide-toggle-right",
    "boolean-false": "lucide-toggle-left",
    null: "lucide-minus",
    object: "lucide-braces",
    array: "lucide-brackets",
    function: "lucide-parentheses",
    param: "lucide-info",
  };
  return iconMap[type] || null;
}
