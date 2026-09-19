import { lookupWorkflowMethodDoc, walkScope } from "../expression-context";

export function buildArgumentInfo(
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
    const doc =
      lookupWorkflowMethodDoc(ctx.parentPath, ctx.methodName) ||
      lookupMethodDoc(ctx.methodName, parentValue);
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
