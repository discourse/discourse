import {
  completionSection,
  standardCompletionSections,
} from "discourse/lib/code-editor-completion-sections";
import {
  ARRAY_METHODS,
  BOOLEAN_METHODS,
  DATE_METHODS,
  GLOBAL_COMPLETIONS,
  GLOBAL_DOCS,
  GLOBAL_STATIC_METHODS,
  lookupMethodDoc,
  NUMBER_METHODS,
  STRING_METHODS,
} from "./completions-data.js";
import { expressionLanguage } from "./lang-expression/index.js";
import {
  analyzePropertyAccess,
  isInsideExpression,
  isInsideExpressionAt,
  resolveNodeValue,
} from "./tree-utils.js";

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
  section: completionSection,
  globalDocs: GLOBAL_DOCS,
  sections: standardCompletionSections(),
  globalCompletions: GLOBAL_COMPLETIONS,
  globalStaticMethods: GLOBAL_STATIC_METHODS,
};
