// Converts snake_case to camelCase, useful for converting
// rails serializer attributes to JS object keys.
export function snakeCaseToCamelCase(str) {
  return str.replace(/_([a-z])/g, (match, letter) => letter.toUpperCase());
}

// Converts camelCase to dash-case, useful for converting
// JS object keys to HTML attributes.
export function camelCaseToDash(str) {
  return str.replace(/([a-zA-Z])(?=[A-Z])/g, "$1-").toLowerCase();
}

// Converts camelCase to snake_case, useful for converting
// JS object keys to Rails serializer attributes.
export function camelCaseToSnakeCase(str) {
  return str.replace(/([a-zA-Z])(?=[A-Z])/g, "$1_").toLowerCase();
}
