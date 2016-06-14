export function register(helper, codeName, args, emitter) {
  // Optional second param for args
  if (typeof args === "function") {
    emitter = args;
    args = {};
  }

  helper.replaceBlock({
    start: new RegExp("\\[" + codeName + "(=[^\\[\\]]+)?\\]([\\s\\S]*)", "igm"),
    stop: new RegExp("\\[\\/" + codeName + "\\]", "igm"),
    emitter(blockContents, matches) {
      const options = helper.getOptions();
      while (blockContents.length && (typeof blockContents[0] === "string" || blockContents[0] instanceof String)) {
        blockContents[0] = String(blockContents[0]).replace(/^\s+/, '');
        if (!blockContents[0].length) {
          blockContents.shift();
        } else {
          break;
        }
      }

      let contents = [];
      if (blockContents.length) {
        const nextContents = blockContents.slice(1);
        blockContents = this.processBlock(blockContents[0], nextContents).concat(nextContents);

        blockContents.forEach(bc => {
          if (typeof bc === "string" || bc instanceof String) {
            var processed = this.processInline(String(bc));
            if (processed.length) {
              contents.push(['p'].concat(processed));
            }
          } else {
            contents.push(bc);
          }
        });
      }
      if (!args.singlePara && contents.length === 1 && contents[0] instanceof Array && contents[0][0] === "para") {
        contents[0].shift();
        contents = contents[0];
      }
      const result = emitter(contents, matches[1] ? matches[1].replace(/^=|\"/g, '') : null, options);
      return args.noWrap ? result : ['p', result];
    }
  });
};

export function setup(helper) {

  helper.whiteList(['span.bbcode-b', 'span.bbcode-i', 'span.bbcode-u', 'span.bbcode-s']);

  function replaceBBCode(tag, emitter, opts) {
    const start = `[${tag}]`;
    const stop = `[/${tag}]`;

    opts = opts || {};
    opts = _.merge(opts, { start, stop, emitter });
    helper.inlineBetween(opts);

    opts = _.merge(opts, { start: start.toUpperCase(), stop: stop.toUpperCase(), emitter });
    helper.inlineBetween(opts);
  };

  function rawBBCode(tag, emitter) {
    replaceBBCode(tag, emitter, { rawContents: true });
  }

  function removeEmptyLines(contents) {
    const result = [];
    for (let i=0; i < contents.length; i++) {
      if (contents[i] !== "\n") { result.push(contents[i]); }
    }
    return result;
  }

  function replaceBBCodeParamsRaw(tag, emitter) {
    var opts = {
      rawContents: true,
      emitter(contents) {
        const m = /^([^\]]+)\]([\S\s]*)$/.exec(contents);
        if (m) { return emitter.call(this, m[1], m[2]); }
      }
    };

    helper.inlineBetween(_.merge(opts, { start: "[" + tag + "=", stop: "[/" + tag + "]" }));

    tag = tag.toUpperCase();
    helper.inlineBetween(_.merge(opts, { start: "[" + tag + "=", stop: "[/" + tag + "]" }));
  }

  replaceBBCode('b', contents => ['span', {'class': 'bbcode-b'}].concat(contents));
  replaceBBCode('i', contents => ['span', {'class': 'bbcode-i'}].concat(contents));
  replaceBBCode('u', contents => ['span', {'class': 'bbcode-u'}].concat(contents));
  replaceBBCode('s', contents => ['span', {'class': 'bbcode-s'}].concat(contents));

  replaceBBCode('ul', contents => ['ul'].concat(removeEmptyLines(contents)));
  replaceBBCode('ol', contents => ['ol'].concat(removeEmptyLines(contents)));
  replaceBBCode('li', contents => ['li'].concat(removeEmptyLines(contents)));

  rawBBCode('img', href => ['img', {href}]);
  rawBBCode('email', contents => ['a', {href: "mailto:" + contents, 'data-bbcode': true}, contents]);

  replaceBBCode('url', contents => {
    if (!Array.isArray(contents)) { return; }
    if (contents.length === 1 && contents[0][0] === 'a') {
      // single-line bbcode links shouldn't be oneboxed, so we mark this as a bbcode link.
      if (typeof contents[0][1] !== 'object') { contents[0].splice(1, 0, {}); }
      contents[0][1]['data-bbcode'] = true;
    }
    return ['concat'].concat(contents);
  });

  replaceBBCodeParamsRaw('url', function(param, contents) {
    const url = param.replace(/(^")|("$)/g, '');
    return ['a', {'href': url}].concat(this.processInline(contents));
  });

  replaceBBCodeParamsRaw("email", function(param, contents) {
    return ['a', {href: "mailto:" + param, 'data-bbcode': true}].concat(contents);
  });

  helper.onParseNode(event => {
    if (!Array.isArray(event.node)) { return; }
    const result = [event.node[0]];
    const nodes = event.node.slice(1);
    for (let i = 0; i < nodes.length; i++) {
      if (Array.isArray(nodes[i]) && nodes[i][0] === 'concat') {
        for (let j = 1; j < nodes[i].length; j++) { result.push(nodes[i][j]); }
      } else {
        result.push(nodes[i]);
      }
    }
    for (let i = 0; i < result.length; i++) { event.node[i] = result[i]; }
  });

  helper.replaceBlock({
    start: /(\[code\])([\s\S]*)/igm,
    stop: /\[\/code\]/igm,
    rawContents: true,

    emitter(blockContents) {
      const options = helper.getOptions();
      const inner = blockContents.join("\n");
      const defaultCodeLang = options.defaultCodeLang;
      return ['p', ['pre', ['code', {'class': `lang-${defaultCodeLang}`}, inner]]];
    }
  });
}
