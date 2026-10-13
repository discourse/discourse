import { builders as b } from "@glimmer/syntax";

// Resolved at runtime through the loader shims in `discourse/app/loader-shims`,
// which point these names at the vendored helpers in `discourse/app/lib`.
const HELPER_MODULE_PREFIX = "ember-this-fallback";

const DEPRECATION_OPTIONS = {
  id: "ember-this-fallback.this-property-fallback",
  until: "n/a",
  for: "ember-this-fallback",
  url: "https://deprecations.emberjs.com/v3.x#toc_this-property-fallback",
  since: { available: "0.2.0" },
};

// https://github.com/embroider-build/embroider/blob/137fcab/packages/compat/src/resolver-transform.ts#L46-L86
const GLOBALS = [
  "-get-dynamic-var",
  "-in-element",
  "-with-dynamic-vars",
  "action",
  "array",
  "component",
  "concat",
  "debugger",
  "each-in",
  "each",
  "fn",
  "get",
  "has-block-params",
  "has-block",
  "hasBlock",
  "hasBlockParams",
  "hash",
  "helper",
  "if",
  "in-element",
  "input",
  "let",
  "link-to",
  "loc",
  "log",
  "modifier",
  "mount",
  "mut",
  "on",
  "outlet",
  "partial",
  "query-params",
  "readonly",
  "textarea",
  "unbound",
  "unique-id",
  "unless",
  "with",
  "yield",
];

function camelCase(str) {
  return String(str)
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .map((word, index) => {
      const lower = word.toLowerCase();
      return index === 0 ? lower : lower[0].toUpperCase() + lower.slice(1);
    })
    .join("");
}

function classify(str) {
  return str
    .split("/")
    .map((part) => {
      const camel = camelCase(part);
      return camel.charAt(0).toUpperCase() + camel.slice(1);
    })
    .join("::");
}

class ScopeFrame {
  constructor(locals, parent) {
    this.locals = locals;
    this.parent = parent;
  }

  has(local) {
    return this.locals.includes(local) || (this.parent?.has(local) ?? false);
  }

  child(locals) {
    return new ScopeFrame(locals, this);
  }
}

/** Tracks the stack of local variable names currently in scope. */
class ScopeStack {
  #head = new ScopeFrame(GLOBALS, null);

  get size() {
    let length = 0;
    let current = this.#head;
    while (current) {
      length++;
      current = current.parent;
    }
    return length;
  }

  push(locals) {
    this.#head = this.#head.child(locals);
  }

  pop() {
    const parent = this.#head.parent;
    if (parent === null) {
      throw new Error("unbalanced push and pop");
    }
    this.#head = parent;
  }

  has(name) {
    return this.#head.has(name);
  }
}

function headNotInScope(head, scope) {
  return head.type === "VarHead" && !scope.has(head.name);
}

function unusedNameLike(desiredName, scope) {
  let candidate = desiredName;
  let counter = 0;
  while (scope.has(candidate)) {
    candidate = `${desiredName}${counter++}`;
  }
  return candidate;
}

function isNode(value, type) {
  return type ? value?.type === type : !!value;
}

function stringifyPath(expr) {
  return [expr.head.name, ...expr.tail].join(".");
}

function needsFallback(expr, scope) {
  return expr.type === "PathExpression" && headNotInScope(expr.head, scope);
}

function mustacheNeedsFallback(node, scope) {
  return (
    node.params.length === 0 &&
    node.hash.pairs.length === 0 &&
    needsFallback(node.path, scope)
  );
}

function bindAddonHelper(helperName, { bindImport, bindingTarget }) {
  return bindImport(
    `${HELPER_MODULE_PREFIX}/${helperName}`,
    "default",
    bindingTarget,
    { nameHint: camelCase(helperName) }
  );
}

/** Rewrites `{{property.value}}` to `{{this.property.value}}`. */
function buildtimeExpressionFallback(expr) {
  return b.path(`this.${stringifyPath(expr)}`, expr.loc);
}

function runtimeExpressionFallback(expr, deprecation, binding) {
  const thisFallbackHelper = bindAddonHelper("this-fallback-helper", binding);
  return b.sexpr(thisFallbackHelper, [
    b.path("this"),
    b.string(stringifyPath(expr.path)),
    deprecation ? b.string(JSON.stringify(deprecation)) : b.boolean(false),
  ]);
}

/**
 * Wraps a node in `{{#let (hash x=(tryLookupHelper 'x')) as |maybeHelpers|}}`
 * so ambiguous heads can be resolved as helpers at runtime.
 */
function wrapWithTryLookup(node, headsToLookup, blockParam, binding) {
  const tryLookupHelper = bindAddonHelper("try-lookup-helper", binding);
  const lookupsHash = b.sexpr(
    b.path("hash"),
    undefined,
    b.hash(
      [...headsToLookup].map((headName) =>
        b.pair(headName, b.sexpr(tryLookupHelper, [b.string(headName)]))
      )
    )
  );

  return b.block(
    b.path("let"),
    [lookupsHash],
    null,
    b.blockItself([node], [blockParam]),
    null,
    node.loc
  );
}

function helperOrExpressionFallback(
  blockParamName,
  expr,
  deprecation,
  binding
) {
  const maybeHelper = `${blockParamName}.${expr.path.head.name}`;
  return b.sexpr(b.path("if"), [
    b.path(maybeHelper),
    b.sexpr(b.path(maybeHelper)),
    runtimeExpressionFallback(expr, deprecation, binding),
  ]);
}

/**
 * Resolves `{{property}}` as a component if one exists, otherwise as a helper,
 * otherwise as a `this` property.
 */
function ambiguousStatementFallback(expr, path, scope, deprecation, binding) {
  const headName = expr.path.head.name;
  const isComponent = bindAddonHelper("is-component", binding);
  const blockParamName = unusedNameLike("maybeHelpers", scope);

  const tryLookup = wrapWithTryLookup(
    b.mustache(
      helperOrExpressionFallback(blockParamName, expr, deprecation, binding)
    ),
    new Set([headName]),
    blockParamName,
    binding
  );

  return b.block(
    b.path("if"),
    [b.sexpr(isComponent, [b.string(headName)])],
    null,
    b.blockItself([b.element({ name: classify(headName), selfClosing: true })]),
    b.blockItself([tryLookup]),
    path.node.loc
  );
}

function maybeAddDeprecationsHelper(template, deprecations, binding) {
  if (deprecations.length > 0) {
    const deprecationsHelper = bindAddonHelper("deprecations-helper", binding);
    template.body.push(
      b.mustache(b.path(deprecationsHelper), [
        b.string(JSON.stringify(deprecations)),
      ])
    );
  }
}

class ThisFallbackPlugin {
  #deprecations = [];
  #scopeStack = new ScopeStack();

  constructor(name, env) {
    this.name = name;
    this.env = env;

    this.visitor = {
      Template: this.#handleTemplate(),
      Block: this.#handleBlock(),
      ElementNode: {
        keys: { children: this.#handleBlock() },
        ...this.#handleAttrNodes(),
      },
      MustacheStatement: {
        ...this.#handleCall(),
        ...this.#handleMustache(),
      },
      BlockStatement: this.#handleCall(),
      ElementModifierStatement: this.#handleCall(),
      SubExpression: this.#handleCall(),
    };
  }

  get #binding() {
    return (bindingTarget) => ({
      bindImport: (...args) => this.env.meta.jsutils.bindImport(...args),
      bindingTarget,
    });
  }

  #handleBlock() {
    return {
      enter: (node) => {
        if (this.env.strictMode) {
          return;
        }
        this.#scopeStack.push(node.blockParams);
      },
      exit: () => {
        if (this.env.strictMode) {
          return;
        }
        this.#scopeStack.pop();
      },
    };
  }

  #handleAttrNodes() {
    return {
      enter: (elementNode, elementPath) => {
        if (this.env.strictMode) {
          return;
        }

        const ambiguousHeads = new Set();
        const blockParamName = unusedNameLike("maybeHelpers", this.#scopeStack);
        const binding = this.#binding(elementPath);

        for (const attrNode of elementNode.attributes) {
          const value = attrNode.value;

          if (
            isNode(value, "MustacheStatement") &&
            mustacheNeedsFallback(value, this.#scopeStack)
          ) {
            const headName = value.path.head.name;
            if (attrNode.name.startsWith("@")) {
              this.#deprecateFallback(headName);
              attrNode.value.path = buildtimeExpressionFallback(value.path);
            } else {
              ambiguousHeads.add(headName);
              attrNode.value.path = helperOrExpressionFallback(
                blockParamName,
                value,
                this.#makeFallbackDeprecation(headName),
                binding
              );
            }
          } else if (isNode(value, "ConcatStatement")) {
            for (const part of value.parts) {
              if (
                isNode(part, "MustacheStatement") &&
                mustacheNeedsFallback(part, this.#scopeStack)
              ) {
                const headName = part.path.head.name;
                ambiguousHeads.add(headName);
                part.path = helperOrExpressionFallback(
                  blockParamName,
                  part,
                  this.#makeFallbackDeprecation(headName),
                  binding
                );
              }
            }
          }
        }

        if (ambiguousHeads.size > 0) {
          return wrapWithTryLookup(
            elementPath.node,
            ambiguousHeads,
            blockParamName,
            binding
          );
        }

        return elementNode;
      },
    };
  }

  #handleCall() {
    return {
      keys: {
        params: (node) => {
          if (this.env.strictMode) {
            return;
          }
          node.params = node.params.map((expr) => {
            if (needsFallback(expr, this.#scopeStack)) {
              this.#deprecateFallback(expr.head.name);
              return buildtimeExpressionFallback(expr);
            }
            return expr;
          });
        },
        hash: (node) => {
          if (this.env.strictMode) {
            return;
          }
          node.hash.pairs = node.hash.pairs.map((pair) => {
            const { key, value: expr, loc } = pair;
            if (needsFallback(expr, this.#scopeStack)) {
              this.#deprecateFallback(expr.head.name);
              return b.pair(key, buildtimeExpressionFallback(expr), loc);
            }
            return pair;
          });
        },
      },
    };
  }

  #handleMustache() {
    return {
      enter: (node, path) => {
        if (this.env.strictMode) {
          return;
        }

        if (!mustacheNeedsFallback(node, this.#scopeStack)) {
          return node;
        }

        if (path.parentNode?.type === "AttrNode") {
          throw new Error(
            "unexpected ambiguous mustache expression in attribute value"
          );
        }

        const headName = node.path.head.name;

        if (node.path.tail.length > 0) {
          this.#deprecateFallback(headName);
          node.path = buildtimeExpressionFallback(node.path);
          return node;
        }

        return ambiguousStatementFallback(
          node,
          path,
          this.#scopeStack,
          this.#makeFallbackDeprecation(headName),
          this.#binding(path)
        );
      },
    };
  }

  #handleTemplate() {
    return {
      exit: (node, path) => {
        if (this.env.strictMode) {
          return;
        }

        if (this.#scopeStack.size !== 1) {
          throw new Error(
            `unbalanced ScopeStack push and pop, ScopeStack size is ${this.#scopeStack.size}`
          );
        }

        maybeAddDeprecationsHelper(
          node,
          this.#deprecations,
          this.#binding(path)
        );
      },
    };
  }

  #deprecateFallback(headName) {
    this.#deprecations.push(this.#makeFallbackDeprecation(headName));
  }

  #makeFallbackDeprecation(headName) {
    return [
      `The \`${headName}\` property path was used in the \`${this.env.moduleName}\` template without using \`this\`. This fallback behavior has been deprecated, all properties must be looked up on \`this\` when used in the template: {{this.${headName}}}`,
      false,
      DEPRECATION_OPTIONS,
    ];
  }
}

export default function buildThisFallbackPlugin() {
  return (env) => {
    if (!env.meta.jsutils) {
      throw new Error(
        "The this-fallback plugin relies on the JSUtils from babel-plugin-ember-template-compilation, but none were found."
      );
    }

    return new ThisFallbackPlugin("ember-this-fallback", env);
  };
}
