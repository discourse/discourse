function sourceRoot(node, doc) {
  while (["MemberExpression", "SubscriptExpression"].includes(node?.name)) {
    node = node.firstChild;
  }
  return node?.name === "VariableName"
    ? doc.sliceString(node.from, node.to)
    : null;
}

// The placeholder lets the parser recognize an unfinished expression without
// committing an edit or interpreting the template ourselves.
export function liquidDropContext(state, pos, cmLanguage) {
  const placeholder = "__workflow_drop__";
  const probe = state.update({
    changes: { from: pos, insert: placeholder },
  }).state;
  const end = pos + placeholder.length;
  const tree = cmLanguage.ensureSyntaxTree(probe, end);
  if (!tree) {
    return null;
  }

  const { doc } = probe;
  const read = (node) => node && doc.sliceString(node.from, node.to);
  const at = tree.resolve(pos + 1, 0);
  const expression =
    at.name === "VariableName" && at.from === pos && at.to === end;
  if (!expression && at.name !== "Text") {
    return null;
  }

  const directives = [];
  let container;
  for (let node = at.parent; node; node = node.parent) {
    if (
      ["CommentDirective", "CaptureDirective", "TableDirective"].includes(
        node.name
      )
    ) {
      return null;
    }
    if (!container && ["Tag", "Interpolation"].includes(node.name)) {
      container = node;
    }
    if (node.name === "ForDirective") {
      const tag = node.firstChild;
      if (pos < tag.to) {
        return null;
      }
      if (
        node
          .getChildren("Tag")
          .some((child) => child.from < pos && child.getChild("else"))
      ) {
        return null;
      }
      directives.unshift(node);
    }
  }

  if (expression) {
    if (container?.name === "Tag") {
      const assignment = container.getChild("AssignmentExpression");
      if (
        !container.getChild("echo") &&
        !(assignment && pos > assignment.getChild("AssignOp")?.to)
      ) {
        return null;
      }
    } else if (container?.name !== "Interpolation") {
      return null;
    }
  } else if (container) {
    return null;
  }

  const loops = [];
  for (const directive of directives) {
    const tag = directive.firstChild;
    const binding = tag.getChild("VariableName");
    const source = tag.getChild("in")?.nextSibling;
    const root = sourceRoot(source, doc);
    const path = source && read(source).replace(/\s/g, "");
    const direct = path === "items" || /^inputs\[\d+\]$/.test(path);
    const nested =
      source?.name === "MemberExpression" &&
      loops.some((loop) => loop.name === root);
    if (
      !binding ||
      (!direct && !nested) ||
      (direct && loops.some((loop) => loop.name === root))
    ) {
      return null;
    }
    const name = read(binding);
    if (
      [
        "items",
        "inputs",
        "forloop",
        "vars",
        "execution",
        "site_settings",
      ].includes(name) ||
      (name === "item" &&
        !["items", "inputs[0]"].includes(path) &&
        !loops.some((loop) => ["items", "inputs[0]"].includes(loop.path)))
    ) {
      return null;
    }
    const parameters = tag
      .getChildren("Parameter")
      .map((node) => read(node.getChild("ParameterName")));
    if (
      parameters.some(
        (parameter) => !["reversed", "offset", "limit"].includes(parameter)
      )
    ) {
      return null;
    }
    loops.push({
      name,
      path,
      reversed: parameters.includes("reversed"),
      offset: parameters.includes("offset"),
    });
  }

  // A prior write may replace a renderer collection or an active loop alias.
  // Decline that context instead of evaluating assignments or capture bodies.
  const protectedNames = new Set([
    "items",
    "inputs",
    "item",
    "forloop",
    "vars",
    "execution",
    "site_settings",
    ...loops.map((loop) => loop.name),
  ]);
  let overwritten = false;
  tree.iterate({
    to: pos,
    enter: ({ node, name }) => {
      if (name !== "Tag") {
        return;
      }
      const target =
        node.getChild("AssignmentExpression")?.firstChild ??
        (["capture", "increment", "decrement"].some((keyword) =>
          node.getChild(keyword)
        ) &&
          node.getChild("VariableName"));
      if (target && target.to < pos && protectedNames.has(read(target))) {
        overwritten = true;
      }
    },
  });
  return overwritten ? null : { loops, expression };
}
