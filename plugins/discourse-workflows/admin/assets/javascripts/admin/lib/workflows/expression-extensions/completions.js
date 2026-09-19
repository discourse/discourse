import { lookupWorkflowMethodDoc, walkScope } from "../expression-context";
import { buildDollarVars } from "./dollar-vars";

// Extends core's generic analyzePropertyAccess with workflow-specific
// patterns: $('Node Name') references and $-prefixed variables.
function buildAnalyzeAtCursor({ cmLanguage, utils }) {
  const { syntaxTree } = cmLanguage;
  const { analyzePropertyAccess } = utils;

  return function analyzeAtCursor(state, pos) {
    const tree = syntaxTree(state);
    const node = tree.resolveInner(pos, -1);
    const doc = state.doc;

    // $(' or $(" — node reference
    const lb = doc.sliceString(Math.max(0, pos - 3), pos);
    if (lb === "$('" || lb === '$("') {
      return { kind: "nodeRef", from: pos, pos };
    }

    // $('NodeName') as a complete CallExpression
    let cur = node;
    while (cur) {
      if (cur.name === "CallExpression") {
        const callee = cur.firstChild;
        if (callee && doc.sliceString(callee.from, callee.to) === "$") {
          const argList = cur.getChild("ArgList");
          if (argList && pos > argList.from && pos <= argList.to) {
            return { kind: "nodeRef", from: argList.from + 1, pos };
          }
        }
      }
      cur = cur.parent;
    }

    const result = analyzePropertyAccess(state, pos);

    if (result.kind === "identifier" && result.partial?.startsWith("$")) {
      return { ...result, kind: "dollar" };
    }

    return result;
  };
}

const EXPRESSION_TOKEN_NAMES = new Set([
  "VariableName",
  "PropertyName",
  "Number",
  "String",
  "BooleanLiteral",
  ")",
  "]",
  "}",
]);

function applyMethodCompletion(
  view,
  completion,
  from,
  to,
  { insertCompletionText, pickedCompletion }
) {
  const afterCursor = view.state.doc.sliceString(to, to + 1);

  if (afterCursor === "(") {
    view.dispatch({
      ...insertCompletionText(view.state, completion.label, from, to),
      annotations: pickedCompletion.of(completion),
    });
    return;
  }

  const insert = `${completion.label}()`;
  const hasArgs = completion.detail && !completion.detail.startsWith("()");
  const anchor = from + completion.label.length + (hasArgs ? 1 : 2);
  view.dispatch({
    ...insertCompletionText(view.state, insert, from, to),
    selection: { anchor },
    annotations: pickedCompletion.of(completion),
  });
}

function withMethodApply(option, cmAutocomplete) {
  if (option.type === "method" || option.type === "function") {
    return {
      ...option,
      apply: (view, completion, from, to) =>
        applyMethodCompletion(view, completion, from, to, cmAutocomplete),
    };
  }
  return option;
}

function escapeQuotedString(value, quote) {
  return String(value).replace(/\\/g, "\\\\").replaceAll(quote, `\\${quote}`);
}

export function buildCompletions(cmParams, { scope, ancestorNodes, sections }) {
  const { cmAutocomplete, cmLanguage, cmView, utils } = cmParams;
  const { autocompletion, completionKeymap } = cmAutocomplete;
  const { syntaxTree } = cmLanguage;
  const { keymap } = cmView;
  const {
    isInsideExpression,
    globalCompletions,
    globalStaticMethods,
    methodsForType,
  } = utils;

  const analyzeAtCursor = buildAnalyzeAtCursor(cmParams);
  const dollarVars = buildDollarVars(scope, sections);
  const globalOptions = globalCompletions.map((g) =>
    withMethodApply({ ...g, section: sections.globals }, cmAutocomplete)
  );
  const methodOption = (m) =>
    withMethodApply({ ...m, section: sections.methods }, cmAutocomplete);

  const completer = (context) => {
    if (!isInsideExpression(context)) {
      return null;
    }

    const ctx = analyzeAtCursor(context.state, context.pos);

    switch (ctx.kind) {
      case "property": {
        const target = walkScope(scope, ctx.object);
        if (target == null) {
          return null;
        }

        const options = [];

        const statics = globalStaticMethods[ctx.object] || [];
        for (const m of [...statics, ...methodsForType(target)]) {
          options.push(methodOption(m));
        }

        if (typeof target === "object" && target !== null) {
          for (const name of Object.keys(target)) {
            const value = target[name];
            if (typeof value === "function") {
              const methodDoc = lookupWorkflowMethodDoc(ctx.object, name);
              options.push(
                methodOption({
                  label: name,
                  type: "method",
                  detail: methodDoc?.detail || "()",
                  info: methodDoc?.info,
                })
              );
              continue;
            }
            options.push({
              label: name,
              type:
                typeof value === "object" && value !== null
                  ? "property"
                  : "variable",
              detail: Array.isArray(value) ? "array" : typeof value,
              section: sections.properties,
            });
          }
        }

        if (!options.length) {
          return null;
        }
        return { from: ctx.from, options, filter: true, validFor: /^[\w$]*$/ };
      }

      case "nodeRef": {
        const charBefore = context.state.doc.sliceString(
          ctx.from - 1,
          ctx.from
        );
        const q = charBefore === '"' ? '"' : "'";
        const prefix = charBefore === "'" || charBefore === '"' ? "" : q;
        return {
          from: ctx.from,
          options: ancestorNodes.map((a) => ({
            label: a.node.name,
            apply: `${prefix}${escapeQuotedString(a.node.name, q)}${q})`,
            type: "variable",
            detail: a.node.type,
            section: sections.nodes,
          })),
          filter: true,
        };
      }

      case "bracket": {
        const target = walkScope(scope, ctx.object);
        if (!target || typeof target !== "object") {
          return null;
        }
        return {
          from: ctx.from,
          options: Object.keys(target)
            .filter((k) => typeof target[k] !== "function")
            .map((name) => ({
              label: name,
              apply: `'${escapeQuotedString(name, "'")}']`,
              type: "property",
              section: sections.properties,
            })),
          filter: true,
        };
      }

      case "dollar":
        return { from: ctx.from, options: dollarVars, filter: true };

      case "identifier": {
        const charBefore = context.state.doc.sliceString(
          Math.max(0, ctx.from - 1),
          ctx.from
        );
        if (charBefore === ".") {
          return null;
        }
        return { from: ctx.from, options: globalOptions, filter: true };
      }

      case "blank": {
        if (!context.explicit) {
          return null;
        }
        const prevNode = syntaxTree(context.state).resolveInner(
          ctx.from - 1,
          -1
        );
        if (ctx.from > 0 && EXPRESSION_TOKEN_NAMES.has(prevNode.name)) {
          return null;
        }
        return {
          from: ctx.from,
          options: [...dollarVars, ...globalOptions],
          filter: true,
        };
      }

      default:
        return null;
    }
  };

  return [
    autocompletion({
      override: [completer],
      activateOnTyping: true,
      // Re-trigger completions after picking $( or any property that
      // ends with "." (e.g. "$json.") so the next level shows immediately.
      // String applies end with "."; function applies (methods) don't match.
      activateOnCompletion: (completion) =>
        completion.label === "$(" || completion.apply?.toString().endsWith("."),
      icons: true,
    }),
    keymap.of(completionKeymap),
  ];
}
