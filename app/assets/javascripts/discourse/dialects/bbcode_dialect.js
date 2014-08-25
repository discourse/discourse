Discourse.BBCode = {};

/**
  Create a simple BBCode tag handler

  @method replaceBBCode
  @param {tag} tag the tag we want to match
  @param {function} emitter the function that creates JsonML for the tag
  @param {Object} opts options to pass to Discourse.Dialect.inlineBetween
    @param {Function} [opts.emitter] The function that will be called with the contents and returns JsonML.
    @param {String} [opts.start] The starting token we want to find
    @param {String} [opts.stop] The ending token we want to find
    @param {String} [opts.between] A shortcut for when the `start` and `stop` are the same.
    @param {Boolean} [opts.rawContents] If true, the contents between the tokens will not be parsed.
    @param {Boolean} [opts.wordBoundary] If true, the match must be on a word boundary
    @param {Boolean} [opts.spaceBoundary] If true, the match must be on a sppace boundary
**/

Discourse.BBCode.register = function(codeName, args, emitter) {

  // Optional second param for args
  if (typeof args === "function") {
    emitter = args;
    args = {};
  }

  Discourse.Dialect.replaceBlock({
    start: new RegExp("\\[" + codeName + "(=[^\\[\\]]+)?\\]([\\s\\S]*)", "igm"),
    stop: new RegExp("\\[\\/" + codeName + "\\]", "igm"),
    emitter: function(blockContents, matches, options) {
      while (blockContents.length && (typeof blockContents[0] === "string" || blockContents[0] instanceof String)) {
        blockContents[0] = String(blockContents[0]).replace(/^\s+/, '');
        if (!blockContents[0].length) {
          blockContents.shift();
        } else {
          break;
        }
      }

      var contents = [];
      if (blockContents.length) {
        var self = this;

        var nextContents = blockContents.slice(1);
        blockContents = this.processBlock(blockContents[0], nextContents).concat(nextContents);

        blockContents.forEach(function (bc) {
          if (typeof bc === "string" || bc instanceof String) {
            var processed = self.processInline(String(bc));
            if (processed.length) {
              contents.push(['p'].concat(processed));
            }
          } else {
            contents.push(bc);
          }
        });
      }
      if (!args.singlePara && contents.length === 1) {
        contents[0].shift();
        contents = contents[0];
      }
      var result = emitter(contents, matches[1] ? matches[1].replace(/^=|\"/g, '') : null, options);
      return args.noWrap ? result : ['p', result];
    }
  });
};

Discourse.BBCode.replaceBBCode = function (tag, emitter, opts) {
  opts = opts || {};
  opts = _.merge(opts, { start: "[" + tag + "]", stop: "[/" + tag + "]", emitter: emitter });
  Discourse.Dialect.inlineBetween(opts);

  tag = tag.toUpperCase();
  opts = _.merge(opts, { start: "[" + tag + "]", stop: "[/" + tag + "]", emitter: emitter });
  Discourse.Dialect.inlineBetween(opts);
};

/**
  Shortcut to call replaceBBCode with `rawContents` as true.

  @method replaceBBCode
  @param {tag} tag the tag we want to match
  @param {function} emitter the function that creates JsonML for the tag
**/
Discourse.BBCode.rawBBCode = function (tag, emitter) {
  Discourse.BBCode.replaceBBCode(tag, emitter, { rawContents: true });
};

/**
  Creates a BBCode handler that accepts parameters. Passes them to the emitter.

  @method replaceBBCodeParamsRaw
  @param {tag} tag the tag we want to match
  @param {function} emitter the function that creates JsonML for the tag
**/
Discourse.BBCode.replaceBBCodeParamsRaw = function (tag, emitter) {
  var opts = {
    rawContents: true,
    emitter: function(contents) {
      var regexp = /^([^\]]+)\]([\S\s]*)$/,
          m = regexp.exec(contents);

      if (m) { return emitter.call(this, m[1], m[2]); }
    }
  };

  Discourse.Dialect.inlineBetween(_.merge(opts, { start: "[" + tag + "=", stop: "[/" + tag + "]" }));

  tag = tag.toUpperCase();
  Discourse.Dialect.inlineBetween(_.merge(opts, { start: "[" + tag + "=", stop: "[/" + tag + "]" }));
};

/**
  Filters an array of JSON-ML nodes, removing nodes that represent empty lines ("\n").

  @method removeEmptyLines
  @param {Array} [contents] Array of JSON-ML nodes
**/
Discourse.BBCode.removeEmptyLines = function (contents) {
  var result = [];
  for (var i=0; i < contents.length; i++) {
    if (contents[i] !== "\n") { result.push(contents[i]); }
  }
  return result;
};

Discourse.BBCode.replaceBBCode('b', function(contents) { return ['span', {'class': 'bbcode-b'}].concat(contents); });
Discourse.BBCode.replaceBBCode('i', function(contents) { return ['span', {'class': 'bbcode-i'}].concat(contents); });
Discourse.BBCode.replaceBBCode('u', function(contents) { return ['span', {'class': 'bbcode-u'}].concat(contents); });
Discourse.BBCode.replaceBBCode('s', function(contents) { return ['span', {'class': 'bbcode-s'}].concat(contents); });
Discourse.Markdown.whiteListTag('span', 'class', /^bbcode-[bius]$/);

Discourse.BBCode.replaceBBCode('ul', function(contents) { return ['ul'].concat(Discourse.BBCode.removeEmptyLines(contents)); });
Discourse.BBCode.replaceBBCode('ol', function(contents) { return ['ol'].concat(Discourse.BBCode.removeEmptyLines(contents)); });
Discourse.BBCode.replaceBBCode('li', function(contents) { return ['li'].concat(Discourse.BBCode.removeEmptyLines(contents)); });

Discourse.BBCode.rawBBCode('img', function(contents) { return ['img', {href: contents}]; });
Discourse.BBCode.rawBBCode('email', function(contents) { return ['a', {href: "mailto:" + contents, 'data-bbcode': true}, contents]; });
Discourse.BBCode.rawBBCode('url', function(contents) { return ['a', {href: contents, 'data-bbcode': true}, contents]; });
Discourse.BBCode.rawBBCode('spoiler', function(contents) {
  if (/<img/i.test(contents)) {
    return ['div', { 'class': 'spoiler' }, contents];
  } else {
    return ['span', { 'class': 'spoiler' }, contents];
  }
});

Discourse.BBCode.replaceBBCodeParamsRaw("url", function(param, contents) {
  return ['a', {href: param, 'data-bbcode': true}].concat(contents);
});

Discourse.BBCode.replaceBBCodeParamsRaw("email", function(param, contents) {
  return ['a', {href: "mailto:" + param, 'data-bbcode': true}].concat(contents);
});

Discourse.BBCode.register('size', function(contents, params) {
  return ['span', {'class': "bbcode-size-" + (parseInt(params, 10) || 1)}].concat(contents);
});
Discourse.Markdown.whiteListTag('span', 'class', /^bbcode-size-\d+$/);

// Handles `[code] ... [/code]` blocks
Discourse.Dialect.replaceBlock({
  start: /(\[code\])([\s\S]*)/igm,
  stop: /\[\/code\]/igm,
  rawContents: true,

  emitter: function(blockContents) {
    var inner = blockContents.join("\n").replace(/^\s+/,'');
    return ['p', ['pre', ['code', {'class': Discourse.SiteSettings.default_code_lang}, inner]]];
  }
});
