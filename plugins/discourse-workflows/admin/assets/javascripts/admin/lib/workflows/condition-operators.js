const OPERATORS = {
  equals: { types: ["string", "integer", "boolean"], needsValue: true },
  notEquals: { types: ["string", "integer", "boolean"], needsValue: true },
  contains: { types: ["string", "array"], needsValue: true },
  notContains: { types: ["string", "array"], needsValue: true },
  empty: { types: ["string", "array"], needsValue: false, implicitValue: null },
  notEmpty: {
    types: ["string", "array"],
    needsValue: false,
    implicitValue: null,
  },
  gt: { types: ["integer"], needsValue: true },
  lt: { types: ["integer"], needsValue: true },
  gte: { types: ["integer"], needsValue: true },
  lte: { types: ["integer"], needsValue: true },
  true: { types: ["boolean"], needsValue: false, implicitValue: true },
  false: { types: ["boolean"], needsValue: false, implicitValue: false },
};

export function operatorsForType(type) {
  return Object.keys(OPERATORS).filter((op) =>
    OPERATORS[op].types.includes(type)
  );
}

export function isSingleValueOperator(operation) {
  return OPERATORS[operation] !== undefined && !OPERATORS[operation].needsValue;
}

export function implicitValueFor(operation) {
  return OPERATORS[operation]?.implicitValue;
}
