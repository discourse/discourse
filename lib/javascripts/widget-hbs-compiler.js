function resolve(path) {
  if (path.indexOf("settings") === 0 || path.indexOf("transformed") === 0) {
    return `this.${path}`;
  }
  return path;
}

function sexpValue(value) {
  if (!value) {
    return;
  }

  let pValue = value.original;
  if (value.type === "StringLiteral") {
    return JSON.stringify(pValue);
  } else if (value.type === "SubExpression") {
    return sexp(value);
  }
  return pValue;
}

function pairsToObj(pairs) {
  let result = [];

  pairs.forEach((p) => {
    result.push(`"${p.key}": ${sexpValue(p.value)}`);
  });

  return `{ ${result.join(", ")} }`;
}

function i18n(node) {
  let key = sexpValue(node.params[0]);

  let hash = node.hash;
  if (hash.pairs.length) {
    return `I18n.t(${key}, ${pairsToObj(hash.pairs)})`;
  }

  return `I18n.t(${key})`;
}

function sexp(value) {
  if (value.path.original === "hash") {
    return pairsToObj(value.hash.pairs);
  }

  if (value.path.original === "concat") {
    let result = [];
    value.params.forEach((p) => {
      result.push(sexpValue(p));
    });
    return result.join(" + ");
  }

  if (value.path.original === "i18n") {
    return i18n(value);
  }
}

function valueOf(value) {
  if (value.type === "SubExpression") {
    return sexp(value);
  } else if (value.type === "PathExpression") {
    return value.original;
  } else if (value.type === "StringLiteral") {
    return JSON.stringify(value.value);
  }
}

function argValue(arg) {
  return valueOf(arg.value);
}

function useHelper(state, name) {
  let id = state.helpersUsed[name];
  if (!id) {
    id = ++state.helperNumber;
    state.helpersUsed[name] = id;
  }
  return `__h${id}`;
}

function mustacheValue(node, state) {
  let path = node.path.original;

  switch (path) {
    case "attach":
      let widgetName = argValue(
        node.hash.pairs.find((p) => p.key === "widget")
      );

      let attrs = node.hash.pairs.find((p) => p.key === "attrs");
      if (attrs) {
        return `this.attach(${widgetName}, ${argValue(attrs)})`;
      }
      return `this.attach(${widgetName}, attrs)`;

      break;
    case "yield":
      return `this.attrs.contents()`;
      break;
    case "i18n":
      return i18n(node);
      break;
    case "avatar":
      let template = argValue(
        node.hash.pairs.find((p) => p.key === "template")
      );
      let username = argValue(
        node.hash.pairs.find((p) => p.key === "username")
      );
      let size = argValue(node.hash.pairs.find((p) => p.key === "size"));
      return `${useHelper(
        state,
        "avatar"
      )}(${size}, { template: ${template}, username: ${username} })`;
      break;
    case "date":
      return `${useHelper(state, "dateNode")}(${valueOf(node.params[0])})`;
      break;
    case "d-icon":
      return `${useHelper(state, "iconNode")}(${valueOf(node.params[0])})`;
      break;
    default:
      // Shortcut: If our mustach has hash arguments, we can assume it's attaching.
      // For example `{{home-logo count=123}}` can become `this.attach('home-logo, { "count": 123 });`
      let hash = node.hash;
      if (hash.pairs.length) {
        let widgetString = JSON.stringify(path);
        // magic: support applying of attrs. This is commonly done like `{{home-logo attrs=attrs}}`
        let firstPair = hash.pairs[0];
        if (firstPair.key === "attrs") {
          return `this.attach(${widgetString}, ${firstPair.value.original})`;
        }

        return `this.attach(${widgetString}, ${pairsToObj(hash.pairs)})`;
      }

      if (node.escaped) {
        return `${resolve(path)}`;
      } else {
        return `new ${useHelper(state, "rawHtml")}({ html: '<span>' + ${resolve(
          path
        )} + '</span>'})`;
      }
      break;
  }
}

class Compiler {
  constructor(ast) {
    this.idx = 0;
    this.ast = ast;

    this.state = {
      helpersUsed: {},
      helperNumber: 0,
    };
  }

  newAcc() {
    return `_a${this.idx++}`;
  }

  processNode(parentAcc, node) {
    let instructions = [];
    let innerAcc;

    switch (node.type) {
      case "Program":
      case "Template":
        node.body.forEach((bodyNode) => {
          instructions = instructions.concat(
            this.processNode(parentAcc, bodyNode)
          );
        });
        break;
      case "ElementNode":
        innerAcc = this.newAcc();
        instructions.push(`var ${innerAcc} = [];`);
        node.children.forEach((child) => {
          instructions = instructions.concat(this.processNode(innerAcc, child));
        });

        if (node.attributes.length) {
          let attributes = [];
          let properties = [];

          node.attributes.forEach((a) => {
            const name = a.name;
            const value =
              a.value.type === "MustacheStatement"
                ? mustacheValue(a.value, this.state)
                : `"${a.value.chars}"`;

            if (a.name === "class") {
              properties.push(`"className":${value}`);
            } else {
              attributes.push(`"${name}":${value}`);
            }
          });

          properties.push(`"attributes":{${attributes.join(", ")}}`);
          const propertiesString = `{${properties.join(", ")}}`;

          instructions.push(
            `${parentAcc}.push(virtualDom.h('${node.tag}', ${propertiesString}, ${innerAcc}));`
          );
        } else {
          instructions.push(
            `${parentAcc}.push(virtualDom.h('${node.tag}', ${innerAcc}));`
          );
        }

        break;

      case "TextNode":
        return `${parentAcc}.push(${JSON.stringify(node.chars)});`;

      case "MustacheStatement":
        const value = mustacheValue(node, this.state);
        if (value) {
          instructions.push(`${parentAcc}.push(${value});`);
        }
        break;
      case "BlockStatement":
        let negate = "";

        switch (node.path.original) {
          case "unless":
            negate = "!";
          case "if":
            instructions.push(
              `if (${negate}${resolve(node.params[0].original)}) {`
            );
            node.program.body.forEach((child) => {
              instructions = instructions.concat(
                this.processNode(parentAcc, child)
              );
            });

            if (node.inverse) {
              instructions.push(`} else {`);
              node.inverse.body.forEach((child) => {
                instructions = instructions.concat(
                  this.processNode(parentAcc, child)
                );
              });
            }
            instructions.push(`}`);
            break;
          case "each":
            const collection = resolve(node.params[0].original);
            instructions.push(`if (${collection} && ${collection}.length) {`);
            instructions.push(
              `  ${collection}.forEach(${node.program.blockParams[0]} => {`
            );
            node.program.body.forEach((child) => {
              instructions = instructions.concat(
                this.processNode(parentAcc, child)
              );
            });
            instructions.push(`  });`);
            instructions.push("}");

            break;
        }
        break;
      default:
        break;
    }

    return instructions.join("\n");
  }

  compile() {
    return this.processNode("_r", this.ast);
  }
}

const loader = typeof Ember !== "undefined" ? Ember.__loader.require : require;

function compile(template, glimmer) {
  if (!glimmer) {
    glimmer = loader("@glimmer/syntax");
  }
  const compiled = glimmer.preprocess(template);
  const compiler = new Compiler(compiled);

  let code = compiler.compile();

  let imports = "";

  Object.keys(compiler.state.helpersUsed).forEach((h) => {
    let id = compiler.state.helpersUsed[h];
    imports += `var __h${id} = __widget_helpers.${h}; `;
  });

  return `function(attrs, state) { ${imports}var _r = [];\n${code}\nreturn _r; }`;
}

exports.compile = compile;

function error(path, state, msg) {
  const filename = state.file.opts.filename;
  return path.replaceWithSourceString(
    `function() { console.error("${filename}: ${msg}"); }`
  );
}

const WidgetHbsCompiler = function (babel) {
  let t = babel.types;
  return {
    visitor: {
      ImportDeclaration(path, state) {
        let node = path.node;
        if (
          t.isLiteral(node.source, { value: "discourse/widgets/hbs-compiler" })
        ) {
          let first = node.specifiers && node.specifiers[0];
          if (!t.isImportDefaultSpecifier(first)) {
            let input = state.file.code;
            let usedImportStatement = input.slice(node.start, node.end);
            let msg = `Only \`import hbs from 'discourse/widgets/hbs-compiler'\` is supported. You used: \`${usedImportStatement}\``;
            throw path.buildCodeFrameError(msg);
          }

          state.importId =
            state.importId ||
            path.scope.generateUidIdentifierBasedOnNode(path.node.id);
          path.scope.rename(first.local.name, state.importId.name);
          path.remove();
        }
      },

      TaggedTemplateExpression(path, state) {
        if (!state.importId) {
          return;
        }

        let tagPath = path.get("tag");
        if (tagPath.node.name !== state.importId.name) {
          return;
        }

        if (path.node.quasi.expressions.length) {
          return error(
            path,
            state,
            "placeholders inside a tagged template string are not supported"
          );
        }

        let template = path.node.quasi.quasis
          .map((quasi) => quasi.value.cooked)
          .join("");

        try {
          path.replaceWithSourceString(
            compile(template, WidgetHbsCompiler.glimmer)
          );
        } catch (e) {
          console.error("widget hbs error", e.toString());
          return error(path, state, e.toString());
        }
      },
    },
  };
};

exports.WidgetHbsCompiler = WidgetHbsCompiler;
