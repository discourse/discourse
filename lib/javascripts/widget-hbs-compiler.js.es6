function resolve(path) {
  if (path.indexOf('settings') === 0 || path.indexOf('transformed') === 0) {
    return `this.${path}`;
  }
  return path;
}

function sexp(value) {
  if (value.path.original === "hash") {

    let result = [];

    value.hash.pairs.forEach(p => {
      let pValue = p.value.original;
      if (p.value.type === "StringLiteral") {
        pValue = JSON.stringify(pValue);
      }

      result.push(`"${p.key}": ${pValue}`);
    });

    return `{ ${result.join(", ")} }`;
  }
}

function argValue(arg) {
  let value = arg.value;
  if (value.type === "SubExpression") {
    return sexp(arg.value);
  } else if (value.type === "PathExpression") {
    return value.original;
  } else if (value.type === "StringLiteral") {
    return JSON.stringify(value.value);
  }
}

function mustacheValue(node, state) {
  let path = node.path.original;

  switch(path) {
    case 'attach':
      let widgetName = argValue(node.hash.pairs.find(p => p.key === "widget"));

      let attrs = node.hash.pairs.find(p => p.key === "attrs");
      if (attrs) {
        return `this.attach(${widgetName}, ${argValue(attrs)})`;
      }
      return `this.attach(${widgetName}, attrs)`;

      break;
    case 'yield':
      return `this.attrs.contents()`;
      break;
    case 'i18n':
      let value;
      if (node.params[0].type === "StringLiteral") {
        value = `"${node.params[0].value}"`;
      } else if (node.params[0].type === "PathExpression") {
        value = resolve(node.params[0].original);
      }

      if (value) {
        return `I18n.t(${value})`;
      }

      break;
    case 'fa-icon':
    case 'd-icon':
      state.helpersUsed.iconNode = true;
      let icon = node.params[0].value;
      return `__iN("${icon}")`;
      break;
    default:
      if (node.escaped) {
        return `${resolve(path)}`;
      } else {
        state.helpersUsed.rawHtml = true;
        return `new __rH({ html: '<span>' + ${resolve(path)} + '</span>'})`;
      }
      break;
  }
}

class Compiler {
  constructor(ast) {
    this.idx = 0;
    this.ast = ast;

    this.state = {
      helpersUsed: {}
    };
  }

  newAcc() {
    return `_a${this.idx++}`;
  }

  processNode(parentAcc, node) {
    let instructions = [];
    let innerAcc;

    switch(node.type) {
      case "Program":
        node.body.forEach(bodyNode => {
          instructions = instructions.concat(this.processNode(parentAcc, bodyNode));
        });
        break;
      case "ElementNode":
        innerAcc = this.newAcc();
        instructions.push(`var ${innerAcc} = [];`);
        node.children.forEach(child => {
          instructions = instructions.concat(this.processNode(innerAcc, child));
        });

        if (node.attributes.length) {

          let attributes = [];
          node.attributes.forEach(a => {
            const name = a.name === 'class' ? 'className' : a.name;
            if (a.value.type === "MustacheStatement") {
              attributes.push(`"${name}":${mustacheValue(a.value, this.state)}`);
            } else {
              attributes.push(`"${name}":"${a.value.chars}"`);
            }
          });

          const attrString = `{${attributes.join(', ')}}`;
          instructions.push(`${parentAcc}.push(virtualDom.h('${node.tag}', ${attrString}, ${innerAcc}));`);
        } else {
          instructions.push(`${parentAcc}.push(virtualDom.h('${node.tag}', ${innerAcc}));`);
        }

        break;

      case "TextNode":
        return `${parentAcc}.push(${JSON.stringify(node.chars)});`;

      case "MustacheStatement":
        const value = mustacheValue(node, this.state);
        if (value) {
          instructions.push(`${parentAcc}.push(${value})`);
        }
        break;
      case "BlockStatement":
        let negate = '';

        switch(node.path.original) {
          case 'unless':
            negate = '!';
          case 'if':
            instructions.push(`if (${negate}${resolve(node.params[0].original)}) {`);
            node.program.body.forEach(child => {
              instructions = instructions.concat(this.processNode(parentAcc, child));
            });

            if (node.inverse) {
              instructions.push(`} else {`);
              node.inverse.body.forEach(child => {
                instructions = instructions.concat(this.processNode(parentAcc, child));
              });
            }
            instructions.push(`}`);
            break;
          case 'each':
            const collection = resolve(node.params[0].original);
            instructions.push(`if (${collection} && ${collection}.length) {`);
            instructions.push(`  ${collection}.forEach(${node.program.blockParams[0]} => {`);
            node.program.body.forEach(child => {
              instructions = instructions.concat(this.processNode(parentAcc, child));
            });
            instructions.push(`  });`);
            instructions.push('}');

            break;
        }
        break;
      default:
        break;
    }

    return instructions.join("\n");
  }

  compile() {
    return this.processNode('_r', this.ast);
  }

}

function compile(template) {
  const preprocessor = Ember.__loader.require('@glimmer/syntax');
  const compiled = preprocessor.preprocess(template);
  const compiler = new Compiler(compiled);

  let code = compiler.compile();

  let imports = '';
  if (compiler.state.helpersUsed.iconNode) {
    imports += "var __iN = Discourse.__widget_helpers.iconNode; ";
  }
  if (compiler.state.helpersUsed.rawHtml) {
    imports += "var __rH = Discourse.__widget_helpers.rawHtml; ";
  }

  return `function(attrs, state) { ${imports}var _r = [];\n${code}\nreturn _r; }`;
}

exports.compile = compile;

function error(path, state, msg) {
  const filename = state.file.opts.filename;
  return path.replaceWithSourceString(`function() { console.error("${filename}: ${msg}"); }`);
}

exports.WidgetHbsCompiler = function(babel) {
  let t = babel.types;
  return {
    visitor: {
      ImportDeclaration(path, state) {
        let node = path.node;
        if (t.isLiteral(node.source, { value: "discourse/widgets/hbs-compiler" })) {
          let first = node.specifiers && node.specifiers[0];
          if (!t.isImportDefaultSpecifier(first)) {
            let input = state.file.code;
            let usedImportStatement = input.slice(node.start, node.end);
            let msg = `Only \`import hbs from 'discourse/widgets/hbs-compiler'\` is supported. You used: \`${usedImportStatement}\``;
            throw path.buildCodeFrameError(msg);
          }

          state.importId = state.importId || path.scope.generateUidIdentifierBasedOnNode(path.node.id);
          path.scope.rename(first.local.name, state.importId.name);
          path.remove();
        }
      },

      TaggedTemplateExpression(path, state) {
        if (!state.importId) { return; }

        let tagPath = path.get('tag');
        if (tagPath.node.name !== state.importId.name) {
          return;
        }

        if (path.node.quasi.expressions.length) {
          return error(path, state, "placeholders inside a tagged template string are not supported");
        }

        let template = path.node.quasi.quasis.map(quasi => quasi.value.cooked).join('');

        try {
          path.replaceWithSourceString(compile(template));
        } catch(e) {
          return error(path, state, e.toString());
        }

      }
    }
  };
};
