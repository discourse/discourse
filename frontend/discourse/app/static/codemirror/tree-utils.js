import { syntaxTree } from "@codemirror/language";

function findDot(memberExpr) {
  for (let child = memberExpr.lastChild; child; child = child.prevSibling) {
    if (child.name === ".") {
      return child.from;
    }
  }
  return null;
}

export function resolveNodeValue(node, doc) {
  if (!node) {
    return null;
  }

  if (node.name === "VariableName" || node.name === "VariableDefinition") {
    return doc.sliceString(node.from, node.to);
  }

  if (node.name === "MemberExpression") {
    const obj = resolveNodeValue(node.firstChild, doc);
    const prop = node.lastChild;
    if (obj && prop && prop.name === "PropertyName") {
      return `${obj}.${doc.sliceString(prop.from, prop.to)}`;
    }
    return obj;
  }

  if (node.name === "CallExpression") {
    const callee = node.firstChild;
    if (callee) {
      const calleeName = doc.sliceString(callee.from, callee.to);
      const argList = node.getChild("ArgList");
      if (argList) {
        const strNode = argList.getChild("String");
        if (strNode) {
          const raw = doc.sliceString(strNode.from, strNode.to);
          return `${calleeName}(${raw})`;
        }
      }
    }
  }

  return null;
}

export function analyzePropertyAccess(state, pos) {
  const tree = syntaxTree(state);
  const node = tree.resolveInner(pos, -1);
  const doc = state.doc;

  let cur = node;
  while (cur) {
    if (cur.name === "MemberExpression") {
      const dotPos = findDot(cur);
      if (dotPos !== null && pos > dotPos) {
        const obj = resolveNodeValue(cur.firstChild, doc);
        const partial = doc.sliceString(dotPos + 1, pos);
        return { kind: "property", object: obj, partial, from: dotPos + 1 };
      }
    }

    if (cur.name === "MemberExpression" && cur.getChild("[")) {
      const obj = resolveNodeValue(cur.firstChild, doc);
      return { kind: "bracket", object: obj, from: pos };
    }

    cur = cur.parent;
  }

  if (node.name === "VariableName" || node.name === "VariableDefinition") {
    const text = doc.sliceString(node.from, pos);
    return { kind: "identifier", partial: text, from: node.from };
  }

  return { kind: "blank", from: pos };
}

export function isInsideExpressionAt(state, pos) {
  const tree = syntaxTree(state);
  let node = tree.resolve(pos, -1);
  while (node) {
    if (node.name === "Expression") {
      return true;
    }
    node = node.parent;
  }
  return false;
}

export function isInsideExpression(context) {
  return isInsideExpressionAt(context.state, context.pos);
}
