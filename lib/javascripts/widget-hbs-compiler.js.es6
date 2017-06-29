function resolve(path) {
  return (path.indexOf('settings') === 0) ? `this.${path}` : path;
}

function mustacheValue(node) {
  let path = node.path.original;

  switch(path) {
    case 'attach':
      const widgetName = node.hash.pairs.find(p => p.key === "widget").value.value;
      return `this.attach("${widgetName}", attrs, state)`;
      break;
    case 'yield':
      return `this.attrs.contents()`;
      break;
    case 'i18n':
      let value;
      if (node.params[0].type === "StringLiteral") {
        value = `"${node.params[0].value}"`;
      } else if (node.params[0].type === "PathExpression") {
        value = node.params[0].original;
      }

      if (value) {
        return `I18n.t(${value})`;
      }

      break;
    case 'fa-icon':
      let icon = node.params[0].value;
      return `virtualDom.h('i.fa.fa-${icon}')`;
      break;
    default:
      return `${resolve(path)}`;
      break;
  }
}

class Compiler {
  constructor(ast) {
    this.idx = 0;
    this.ast = ast;
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
              attributes.push(`"${name}":${mustacheValue(a.value)}`);
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
        const value = mustacheValue(node);
        if (value) {
          instructions.push(`${parentAcc}.push(${value})`);
        }
        break;
      case "BlockStatement":
        switch(node.path.original) {
          case 'if':
            instructions.push(`if (${node.params[0].original}) {`);
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
            const collection = node.params[0].original;
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

  return `function(attrs, state) { var _r = [];\n${compiler.compile()}\nreturn _r; }`;
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
