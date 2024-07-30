function wrapInitializer(path, babel) {
  function needsWrapping(node) {
    if (t.isLiteral(node) && !t.isTemplateLiteral(node)) {
      return false;
    }

    if (
      t.isCallExpression(node) ||
      t.isOptionalCallExpression(node) ||
      t.isNewExpression(node)
    ) {
      return needsWrapping(node.callee) || node.arguments.some(needsWrapping);
    }

    if (t.isTemplateLiteral(node)) {
      return node.expressions.some(needsWrapping);
    }

    if (t.isTaggedTemplateExpression(node)) {
      return needsWrapping(node.tag) || needsWrapping(node.quasi);
    }

    if (t.isArrayExpression(node)) {
      return node.elements.some(needsWrapping);
    }

    if (t.isObjectExpression(node)) {
      return node.properties.some((prop) => {
        if (t.isObjectProperty(prop)) {
          return (
            needsWrapping(prop.value) ||
            (prop.computed && needsWrapping(prop.key))
          );
        }
        if (t.isObjectMethod(prop)) {
          return false;
        }
        return false;
      });
    }

    if (t.isMemberExpression(node) || t.isOptionalMemberExpression(node)) {
      return (
        needsWrapping(node.object) ||
        (node.computed && needsWrapping(node.property))
      );
    }

    if (
      t.isFunctionExpression(node) ||
      t.isArrowFunctionExpression(node) ||
      t.isClassExpression(node)
    ) {
      return false;
    }

    if (t.isThisExpression(node)) {
      return false;
    }

    if (t.isSequenceExpression(node)) {
      return node.expressions.some(needsWrapping);
    }

    // Is an identifier, or anything else not covered above
    return true;
  }

  const { types: t } = babel;
  const { value } = path.node;

  if (value && needsWrapping(value)) {
    path.node.value = t.callExpression(
      t.arrowFunctionExpression([], value),
      []
    );
  }
}

function makeVisitor(babel) {
  return {
    ClassProperty(path) {
      wrapInitializer(path, babel);
    },
    ClassPrivateProperty(path) {
      wrapInitializer(path, babel);
    },
  };
}

module.exports = function wrapClassFields(babel) {
  return {
    post(file) {
      babel.traverse(file.ast, makeVisitor(babel), file.scope, this);
    },
  };
};
