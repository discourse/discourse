import { lookupWorkflowMethodDoc, walkScope } from "../expression-context";
import { lookupDollarVarDoc } from "./dollar-vars";

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

export function buildHoverTooltip({ cmLanguage, cmView, utils }, { scope }) {
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

          const methodDoc =
            lookupWorkflowMethodDoc(parentPath, name) ||
            lookupMethodDoc(name, parentValue);
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

      const varDoc = lookupDollarVarDoc(name);
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
