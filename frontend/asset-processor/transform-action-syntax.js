// backported from https://github.com/emberjs/ember.js/blob/v5.12.0/packages/ember-template-compiler/lib/plugins/transform-action-syntax.ts

/**
  A Glimmer2 AST transformation that replaces all instances of

  ```handlebars
 <button {{action 'foo'}}>
 <button onblur={{action 'foo'}}>
 <button onblur={{action (action 'foo') 'bar'}}>
  ```

  with

  ```handlebars
 <button {{action this 'foo'}}>
 <button onblur={{action this 'foo'}}>
 <button onblur={{action this (action this 'foo') 'bar'}}>
  ```

  @private
  @class TransformActionSyntax
*/

function transformActionSyntax({ syntax }) {
  let { builders: b } = syntax;

  return {
    name: "transform-action-syntax",

    visitor: {
      ElementModifierStatement(node) {
        if (isAction(node)) {
          insertThisAsFirstParam(node, b);
        }
      },

      MustacheStatement(node) {
        if (isAction(node)) {
          insertThisAsFirstParam(node, b);
        }
      },

      SubExpression(node) {
        if (isAction(node)) {
          insertThisAsFirstParam(node, b);
        }
      },
    },
  };
}

transformActionSyntax.baseDir = () => __dirname;
transformActionSyntax.cacheKey = () => "transform-action-syntax";

module.exports = transformActionSyntax;

function isPath(node) {
  return node.type === "PathExpression";
}

function isAction(node) {
  return isPath(node.path) && node.path.original === "d-action";
}

function insertThisAsFirstParam(node, builders) {
  node.params.unshift(builders.path("this"));
}
