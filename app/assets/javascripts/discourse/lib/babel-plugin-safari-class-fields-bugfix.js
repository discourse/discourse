function wrapInitializer(path, babel) {
  const { types: t } = babel;
  const { value } = path.node;

  // Check if the node has already been transformed
  if (path.node.__wrapped) {
    return;
  }

  if (value && !(t.isLiteral(value) && !t.isTemplateLiteral(value))) {
    path.node.value = t.callExpression(
      t.arrowFunctionExpression([], value),
      []
    );
    // Mark the node as transformed
    path.node.__wrapped = true;
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
