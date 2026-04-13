import {
  ARRAY_METHODS,
  BOOLEAN_METHODS,
  DATE_METHODS,
  GLOBAL_COMPLETIONS,
  GLOBAL_DOCS,
  GLOBAL_STATIC_METHODS,
  lookupMethodDoc,
  NUMBER_METHODS,
  section,
  SECTION_GLOBALS,
  SECTION_METADATA,
  SECTION_METHODS,
  SECTION_PROPERTIES,
  SECTION_RECOMMENDED,
  STRING_METHODS,
} from "./completions-data";
import { expressionLanguage } from "./lang-expression/index";
import {
  analyzePropertyAccess,
  isInsideExpression,
  isInsideExpressionAt,
  resolveNodeValue,
} from "./tree-utils";

function methodsForType(value) {
  if (value === null || value === undefined) {
    return [];
  }
  if (Array.isArray(value)) {
    return ARRAY_METHODS;
  }
  if (value instanceof Date) {
    return DATE_METHODS;
  }
  switch (typeof value) {
    case "string":
      return STRING_METHODS;
    case "number":
      return NUMBER_METHODS;
    case "boolean":
      return BOOLEAN_METHODS;
    default:
      return [];
  }
}

// Generic expression utilities for {{ }} editors. Domain-specific
// analysis (like workflow $() node refs) should extend
// analyzePropertyAccess in the consumer, not here.
export const expressionUtils = {
  expressionLanguage,
  analyzePropertyAccess,
  resolveNodeValue,
  isInsideExpression,
  isInsideExpressionAt,
  lookupMethodDoc,
  methodsForType,
  section,
  globalDocs: GLOBAL_DOCS,
  sections: {
    recommended: SECTION_RECOMMENDED,
    properties: SECTION_PROPERTIES,
    methods: SECTION_METHODS,
    metadata: SECTION_METADATA,
    globals: SECTION_GLOBALS,
  },
  globalCompletions: GLOBAL_COMPLETIONS,
  globalStaticMethods: GLOBAL_STATIC_METHODS,
};
