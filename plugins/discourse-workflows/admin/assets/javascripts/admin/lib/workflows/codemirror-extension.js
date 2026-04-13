import {
  buildScope,
  resolveVariableId,
  walkScope,
  WORKFLOW_VARIABLE_MIME,
} from "./expression-context";

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

const DOLLAR_VAR_DOCS = {
  $json: {
    detail: "object",
    info: "Output data from the previous node. Access fields with dot notation: $json.fieldName",
  },
  trigger: {
    detail: "object",
    info: "Alias for $json \u2014 the trigger node's output data.",
  },
  $site_settings: {
    detail: "object",
    info: "Access Discourse site settings. Example: $site_settings.title",
  },
  $current_user: {
    detail: "object",
    info: "The user who triggered the workflow. Properties: id, username",
  },
  $vars: {
    detail: "object",
    info: "Workflow variables defined in the admin panel.",
  },
  $execution: {
    detail: "object",
    info: "Execution metadata: id, workflow_id, workflow_name",
  },
};

function buildDollarVars(scope, sections) {
  const groups = [
    {
      names: ["$json", "trigger"],
      section: sections.recommended,
      boost: (name) => (name === "$json" ? 10 : 5),
    },
    {
      names: ["$site_settings", "$current_user", "$vars", "$execution"],
      section: sections.metadata,
    },
  ];

  const dollarVars = [];
  for (const group of groups) {
    for (const name of group.names) {
      if (name in scope) {
        const docs = DOLLAR_VAR_DOCS[name] || {};
        const isObject =
          typeof scope[name] === "object" && scope[name] !== null;
        const entry = {
          label: name,
          apply: isObject ? `${name}.` : name,
          type: "variable",
          detail: docs.detail || "object",
          info: docs.info,
          section: group.section,
        };
        if (group.boost) {
          entry.boost = group.boost(name);
        }
        dollarVars.push(entry);
      }
    }
  }
  dollarVars.push({
    label: "$(",
    apply: "$('",
    type: "function",
    detail: "node reference",
    info: "Reference a previous node's output. Example: $('Node Name').item.json",
    section: sections.nodes,
  });
  return dollarVars;
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

function buildCompletions(
  cmParams,
  { scope, ancestorNodes, analyzeAtCursor, sections }
) {
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

  const dollarVars = buildDollarVars(scope, sections);
  const globalOptions = globalCompletions.map((g) =>
    withMethodApply({ ...g, section: sections.globals }, cmAutocomplete)
  );

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

        const statics = globalStaticMethods[ctx.object];
        if (statics) {
          for (const m of statics) {
            options.push(
              withMethodApply(
                { ...m, section: sections.methods },
                cmAutocomplete
              )
            );
          }
        }

        const methods = methodsForType(target);
        for (const m of methods) {
          options.push(
            withMethodApply({ ...m, section: sections.methods }, cmAutocomplete)
          );
        }

        if (typeof target === "object" && target !== null) {
          for (const name of Object.keys(target)) {
            const value = target[name];
            if (typeof value === "function") {
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

      case "nodeRef":
        return {
          from: ctx.from,
          options: ancestorNodes.map((a) => ({
            label: a.node.name,
            apply: `${a.node.name}')`,
            type: "variable",
            detail: a.node.type,
            section: sections.nodes,
          })),
          filter: true,
        };

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
              apply: `'${name.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}']`,
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

function renderTooltipContent(doc) {
  if (!doc) {
    return null;
  }

  if (typeof doc.info === "function") {
    const richContent = doc.info(doc);
    if (richContent) {
      return richContent;
    }
  }

  const el = document.createElement("div");
  el.className = "cm-wf-hover-tooltip";

  const nameEl = document.createElement("div");
  nameEl.className = "cm-wf-hover-tooltip__name";
  nameEl.textContent = doc.label;
  el.appendChild(nameEl);

  if (typeof doc.info === "string") {
    const desc = document.createElement("div");
    desc.className = "cm-wf-hover-tooltip__description";
    desc.textContent = doc.info;
    el.appendChild(desc);
  }

  return el;
}

function makeTooltip(jsNode, content) {
  if (!content) {
    return null;
  }
  return {
    pos: jsNode.from,
    end: jsNode.to,
    above: true,
    create: () => ({ dom: content }),
  };
}

function buildHoverTooltip({ cmLanguage, cmView, utils }, { scope }) {
  const { syntaxTree } = cmLanguage;
  const { hoverTooltip } = cmView;
  const {
    isInsideExpressionAt,
    resolveNodeValue,
    lookupMethodDoc,
    globalDocs,
  } = utils;

  return hoverTooltip(
    (view, pos) => {
      const tree = syntaxTree(view.state);
      const doc = view.state.doc;

      if (!isInsideExpressionAt(view.state, pos)) {
        return null;
      }

      const jsNode = tree.resolveInner(pos, -1);
      const name = doc.sliceString(jsNode.from, jsNode.to);

      if (
        jsNode.name !== "VariableName" &&
        jsNode.name !== "VariableDefinition" &&
        jsNode.name !== "PropertyName"
      ) {
        return null;
      }

      if (jsNode.name === "PropertyName") {
        const memberExpr = jsNode.parent;
        if (memberExpr?.name === "MemberExpression") {
          const parentPath = resolveNodeValue(memberExpr.firstChild, doc);
          const parentValue = walkScope(scope, parentPath);

          const methodDoc = lookupMethodDoc(name, parentValue);
          if (methodDoc) {
            return makeTooltip(jsNode, renderTooltipContent(methodDoc));
          }

          const path = resolveNodeValue(memberExpr, doc);
          const value = walkScope(scope, path);
          if (value !== undefined) {
            const typeStr = Array.isArray(value) ? "array" : typeof value;
            const label =
              typeStr === "string" && value.length < 60
                ? `${name}: "${value}"`
                : `${name}: ${typeStr}`;
            return makeTooltip(jsNode, renderTooltipContent({ label }));
          }
        }
      }

      const varDoc = DOLLAR_VAR_DOCS[name];
      if (varDoc) {
        return makeTooltip(
          jsNode,
          renderTooltipContent({ ...varDoc, label: name })
        );
      }

      const globalDoc = globalDocs.get(name);
      if (globalDoc) {
        return makeTooltip(jsNode, renderTooltipContent(globalDoc));
      }

      return null;
    },
    { hoverTime: 400 }
  );
}

function buildArgumentInfo(
  { cmAutocomplete, cmLanguage, cmState, cmView, utils },
  { scope }
) {
  const { completionStatus } = cmAutocomplete;
  const { syntaxTree } = cmLanguage;
  const { StateField } = cmState;
  const { showTooltip } = cmView;
  const { resolveNodeValue, lookupMethodDoc } = utils;

  function findCallContext(state, pos) {
    const tree = syntaxTree(state);
    const doc = state.doc;
    let node = tree.resolveInner(pos, -1);

    while (node) {
      if (node.name === "ArgList") {
        const call = node.parent;
        if (!call || call.name !== "CallExpression") {
          return null;
        }

        const callee = call.firstChild;
        if (!callee) {
          return null;
        }

        if (
          callee.name === "VariableName" &&
          doc.sliceString(callee.from, callee.to) === "$"
        ) {
          return null;
        }

        let methodName;
        let parentPath;

        if (callee.name === "MemberExpression") {
          const prop = callee.lastChild;
          if (prop?.name === "PropertyName") {
            methodName = doc.sliceString(prop.from, prop.to);
            parentPath = resolveNodeValue(callee.firstChild, doc);
          }
        } else if (callee.name === "VariableName") {
          methodName = doc.sliceString(callee.from, callee.to);
        }

        if (!methodName) {
          return null;
        }

        let argIndex = 0;
        for (let child = node.firstChild; child; child = child.nextSibling) {
          if (child.name === "," && child.to <= pos) {
            argIndex++;
          }
        }

        return { methodName, parentPath, argIndex, callFrom: call.from };
      }
      node = node.parent;
    }
    return null;
  }

  function buildTooltipForCall(ctx, pos) {
    const parentValue = ctx.parentPath
      ? walkScope(scope, ctx.parentPath)
      : null;
    const doc = lookupMethodDoc(ctx.methodName, parentValue);
    if (!doc?.info) {
      return null;
    }

    const content = typeof doc.info === "function" ? doc.info(doc) : null;
    if (!content) {
      return null;
    }

    return {
      pos,
      above: true,
      strictSide: true,
      create: () => ({ dom: content }),
    };
  }

  return StateField.define({
    create: () => ({ tooltip: null, callFrom: null }),
    update(prev, tr) {
      if (!tr.docChanged && !tr.selection) {
        return prev;
      }

      if (completionStatus(tr.state) === "active") {
        return { tooltip: null, callFrom: null };
      }

      const { head } = tr.state.selection.ranges[0];
      const ctx = findCallContext(tr.state, head);
      if (!ctx) {
        return { tooltip: null, callFrom: null };
      }

      if (prev.callFrom === ctx.callFrom) {
        return prev;
      }

      return {
        tooltip: buildTooltipForCall(ctx, head),
        callFrom: ctx.callFrom,
      };
    },
    provide: (f) => showTooltip.compute([f], (state) => state.field(f).tooltip),
  });
}

function buildDragDrop({ cmLanguage, cmView }, { itemPrefix }) {
  const { ensureSyntaxTree } = cmLanguage;
  const { dropCursor, EditorView } = cmView;

  return [
    dropCursor(),
    EditorView.domEventHandlers({
      dragover(event) {
        if (event.dataTransfer.types.includes(WORKFLOW_VARIABLE_MIME)) {
          event.preventDefault();
          event.dataTransfer.dropEffect = "copy";
        }
      },
      drop(event, view) {
        const data = event.dataTransfer.getData(WORKFLOW_VARIABLE_MIME);
        if (!data) {
          return false;
        }

        event.preventDefault();

        let variable;
        try {
          variable = JSON.parse(data);
        } catch {
          return false;
        }

        const variableId = resolveVariableId(variable, itemPrefix);

        let pos = view.posAtCoords({ x: event.clientX, y: event.clientY });
        if (pos === null) {
          pos = view.state.doc.length;
        }

        let inside = false;
        const tree = ensureSyntaxTree(view.state, view.state.doc.length, 100);
        if (tree) {
          for (const side of [-1, 1]) {
            let n = tree.resolve(pos, side);
            while (n) {
              if (n.name === "Expression") {
                inside = pos > n.from + 2 && pos < n.to - 2;
                break;
              }
              n = n.parent;
            }
            if (inside) {
              break;
            }
          }
        }
        const insert = inside ? variableId : `{{ ${variableId} }}`;
        view.dispatch({
          changes: { from: pos, insert },
          selection: { anchor: pos, head: pos + insert.length },
        });
        view.focus();

        return true;
      },
    }),
  ];
}

function buildValidation({ cmLanguage, cmView }) {
  const { syntaxTree } = cmLanguage;
  const { Decoration, ViewPlugin } = cmView;

  const errorMark = Decoration.mark({ class: "cm-wf-error" });

  return ViewPlugin.fromClass(
    class {
      decorations;

      constructor(view) {
        this.decorations = this.build(view.state);
      }

      update(update) {
        if (update.docChanged || update.startState.tree !== update.state.tree) {
          this.decorations = this.build(update.state);
        }
      }

      build(state) {
        const widgets = [];
        const tree = syntaxTree(state);
        const docLen = state.doc.length;

        tree.iterate({
          enter(node) {
            if (node.name === "Expression") {
              const text = state.doc.sliceString(node.from, node.to);
              if (!text.endsWith("}}")) {
                widgets.push(errorMark.range(node.from, docLen));
              }
            }
          },
        });

        return Decoration.set(widgets, true);
      }
    },
    { decorations: (v) => v.decorations }
  );
}

function buildAutoCloseBraces({ cmAutocomplete, cmView }) {
  const { startCompletion } = cmAutocomplete;
  const { EditorView } = cmView;

  return EditorView.inputHandler.of((view, from, to, text) => {
    if (text !== "{") {
      return false;
    }

    const before = view.state.doc.sliceString(Math.max(0, from - 1), from);
    if (before !== "{") {
      return false;
    }

    const after = view.state.doc.sliceString(to, to + 2);
    if (after === "}}") {
      // Already have closing braces — just insert the space and move cursor in
      view.dispatch({
        changes: { from, to, insert: "{  " },
        selection: { anchor: from + 2 },
      });
    } else {
      view.dispatch({
        changes: { from, to, insert: "{  }}" },
        selection: { anchor: from + 2 },
      });
    }

    startCompletion(view);

    return true;
  });
}

function buildInvalidExpressions({ cmState, cmView }) {
  const { StateEffect, StateField } = cmState;
  const { Decoration, EditorView } = cmView;

  const MARKS = {
    valid: Decoration.mark({ class: "cm-wf-valid-expression" }),
    invalid: Decoration.mark({ class: "cm-wf-invalid-expression" }),
    undefined: Decoration.mark({ class: "cm-wf-invalid-expression" }),
    empty: Decoration.mark({ class: "cm-wf-empty-expression" }),
    warning: Decoration.mark({ class: "cm-wf-warning-expression" }),
    pending: Decoration.mark({ class: "cm-wf-pending-expression" }),
  };

  const setExpressionsEffect = StateEffect.define();

  const field = StateField.define({
    create() {
      return Decoration.none;
    },
    update(decorations, tr) {
      decorations = decorations.map(tr.changes);
      for (const effect of tr.effects) {
        if (effect.is(setExpressionsEffect)) {
          decorations = effect.value;
        }
      }
      return decorations;
    },
    provide: (f) => EditorView.decorations.from(f),
  });

  function mark(view, ranges) {
    const widgets = ranges
      .filter(({ from, to }) => from !== undefined && to !== undefined)
      .map(({ from, to, state }) => {
        const m = MARKS[state] || MARKS.invalid;
        return m.range(from, to);
      });
    view.dispatch({
      effects: setExpressionsEffect.of(Decoration.set(widgets, true)),
    });
  }

  function clear(view) {
    view.dispatch({
      effects: setExpressionsEffect.of(Decoration.none),
    });
  }

  return { field, mark, clear };
}

function buildTheme({ cmLanguage, lezerHighlight }) {
  const { HighlightStyle, syntaxHighlighting } = cmLanguage;
  const { tags } = lezerHighlight;

  return syntaxHighlighting(
    HighlightStyle.define([
      { tag: tags.content, class: "cm-wf-text" },
      { tag: tags.brace, class: "cm-wf-brace" },
      { tag: tags.keyword, class: "cm-wf-keyword" },
      { tag: tags.string, class: "cm-wf-string" },
      { tag: tags.number, class: "cm-wf-number" },
      { tag: tags.bool, class: "cm-wf-bool" },
      { tag: tags.null, class: "cm-wf-null" },
      { tag: tags.variableName, class: "cm-wf-variable" },
      { tag: tags.propertyName, class: "cm-wf-property" },
      { tag: tags.function(tags.variableName), class: "cm-wf-function" },
      { tag: tags.function(tags.propertyName), class: "cm-wf-function" },
      { tag: tags.operator, class: "cm-wf-operator" },
      { tag: tags.punctuation, class: "cm-wf-punctuation" },
      { tag: tags.comment, class: "cm-wf-comment" },
    ])
  );
}

export default function workflowExtension(cmParams, domainOpts = {}) {
  const itemPrefix = domainOpts.itemPrefix || "$json";
  const analyzeAtCursor = buildAnalyzeAtCursor(cmParams);
  const SECTION_NODES = cmParams.utils.section("Previous nodes", 1);
  const sections = { ...cmParams.utils.sections, nodes: SECTION_NODES };

  const scope = buildScope(domainOpts);
  const ancestorNodes = domainOpts.ancestorNodes || [];
  const completionOpts = { scope, ancestorNodes, analyzeAtCursor, sections };

  const { field, mark, clear } = buildInvalidExpressions(cmParams);

  return {
    extensions: [
      cmParams.utils.expressionLanguage(),
      buildTheme(cmParams),
      buildValidation(cmParams),
      buildAutoCloseBraces(cmParams),
      ...buildDragDrop(cmParams, { itemPrefix }),
      ...buildCompletions(cmParams, completionOpts),
      buildHoverTooltip(cmParams, completionOpts),
      buildArgumentInfo(cmParams, completionOpts),
      field,
    ],
    markInvalidExpressions: mark,
    clearInvalidExpressions: clear,
  };
}
