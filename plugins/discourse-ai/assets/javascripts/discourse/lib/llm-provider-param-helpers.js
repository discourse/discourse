// Returns whether a provider param value is "active" (non-default, truthy).
// Treats null, undefined, false, "false", "default", and "" as inactive.
export function isParamActive(val) {
  if (val === null || val === undefined || val === false) {
    return false;
  }
  if (val === "false" || val === "default" || val === "") {
    return false;
  }
  return true;
}

// Determines if a provider param field should be hidden based on
// depends_on / hidden_if metadata and current param values.
export function isProviderParamHidden(paramMeta, providerParamsData) {
  if (paramMeta.depends_on) {
    const deps = Array.isArray(paramMeta.depends_on)
      ? paramMeta.depends_on
      : [paramMeta.depends_on];
    if (deps.some((field) => !isParamActive(providerParamsData[field]))) {
      return true;
    }
  }

  if (paramMeta.hidden_if) {
    const conditions = Array.isArray(paramMeta.hidden_if)
      ? paramMeta.hidden_if
      : [paramMeta.hidden_if];
    if (conditions.some((field) => isParamActive(providerParamsData[field]))) {
      return true;
    }
  }

  return false;
}

// Normalizes raw provider_params metadata (from the server) into a
// consistent shape for the editor form.
export function normalizeProviderParams(rawParams) {
  if (!rawParams) {
    return {};
  }

  return Object.entries(rawParams).reduce((acc, [field, value]) => {
    if (typeof value === "string") {
      acc[field] = { type: value };
    } else if (typeof value === "object") {
      if (value.values) {
        value = { ...value };
        value.values = value.values.map((v) => ({ id: v, name: v }));
      }

      acc[field] = {
        type: value.type || "text",
        values: value.values || [],
        default: value.default ?? undefined,
        hidden_if: value.hidden_if ?? undefined,
        depends_on: value.depends_on ?? undefined,
      };
    } else {
      acc[field] = { type: "text" };
    }
    return acc;
  }, {});
}
