const OPERATORS = {
  equals: {
    contexts: {
      workflow: ["string", "number", "boolean"],
      data_table: ["string", "number", "date"],
    },
    needsValue: true,
  },
  notEquals: {
    contexts: {
      workflow: ["string", "number", "boolean"],
      data_table: ["string", "number", "date"],
    },
    needsValue: true,
  },
  contains: {
    contexts: { workflow: ["string", "array"], data_table: ["string"] },
    needsValue: true,
  },
  notContains: {
    contexts: { workflow: ["string", "array"], data_table: ["string"] },
    needsValue: true,
  },
  empty: {
    contexts: {
      workflow: ["string", "array"],
      data_table: ["string", "number", "boolean", "date"],
    },
    needsValue: false,
    implicitValue: null,
  },
  notEmpty: {
    contexts: {
      workflow: ["string", "array"],
      data_table: ["string", "number", "boolean", "date"],
    },
    needsValue: false,
    implicitValue: null,
  },
  gt: {
    contexts: {
      workflow: ["number"],
      data_table: ["string", "number", "date"],
    },
    needsValue: true,
  },
  lt: {
    contexts: {
      workflow: ["number"],
      data_table: ["string", "number", "date"],
    },
    needsValue: true,
  },
  gte: {
    contexts: {
      workflow: ["number"],
      data_table: ["string", "number", "date"],
    },
    needsValue: true,
  },
  lte: {
    contexts: {
      workflow: ["number"],
      data_table: ["string", "number", "date"],
    },
    needsValue: true,
  },
  true: {
    contexts: { workflow: ["boolean"], data_table: ["boolean"] },
    needsValue: false,
    implicitValue: true,
  },
  false: {
    contexts: { workflow: ["boolean"], data_table: ["boolean"] },
    needsValue: false,
    implicitValue: false,
  },
};

export function operatorsForType(type, { context = "workflow" } = {}) {
  return Object.keys(OPERATORS).filter((op) =>
    OPERATORS[op].contexts[context]?.includes(type || "string")
  );
}

export function isSingleValueOperator(operation) {
  return OPERATORS[operation] !== undefined && !OPERATORS[operation].needsValue;
}

export function implicitValueFor(operation) {
  return OPERATORS[operation]?.implicitValue;
}
