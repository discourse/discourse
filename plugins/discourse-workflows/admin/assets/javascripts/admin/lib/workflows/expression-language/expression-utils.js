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
import { expressionLanguage } from "./language.js";
import {
  analyzePropertyAccess,
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

export function buildExpressionUtils(cmParams, javascript) {
  const { syntaxTree } = cmParams.cmLanguage;

  return {
    expressionLanguage: () => expressionLanguage(cmParams, javascript),
    analyzePropertyAccess: (state, pos) =>
      analyzePropertyAccess(syntaxTree(state), state, pos),
    resolveNodeValue,
    isInsideExpression: (context) =>
      isInsideExpressionAt(syntaxTree(context.state), context.pos),
    isInsideExpressionAt: (state, pos) =>
      isInsideExpressionAt(syntaxTree(state), pos),
    lookupMethodDoc,
    methodsForType,
    section: completionSection,
    globalDocs: GLOBAL_DOCS,
    sections: standardCompletionSections(),
    globalCompletions: GLOBAL_COMPLETIONS,
    globalStaticMethods: GLOBAL_STATIC_METHODS,
  };
}
