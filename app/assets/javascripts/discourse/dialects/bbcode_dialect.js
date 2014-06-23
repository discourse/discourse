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
function replaceBBCode(tag, emitter, opts) {
  opts = opts || {};
  opts = _.merge(opts, { start: "[" + tag + "]", stop: "[/" + tag + "]", emitter: emitter });
  Discourse.Dialect.inlineBetween(opts);

  tag = tag.toUpperCase();
  opts = _.merge(opts, { start: "[" + tag + "]", stop: "[/" + tag + "]", emitter: emitter });
  Discourse.Dialect.inlineBetween(opts);
}

/**
  Shortcut to call replaceBBCode with `rawContents` as true.

  @method replaceBBCode
  @param {tag} tag the tag we want to match
  @param {function} emitter the function that creates JsonML for the tag
**/
function rawBBCode(tag, emitter) {
  replaceBBCode(tag, emitter, { rawContents: true });
}

/**
  Creates a BBCode handler that accepts parameters. Passes them to the emitter.

  @method replaceBBCodeParamsRaw
  @param {tag} tag the tag we want to match
  @param {function} emitter the function that creates JsonML for the tag
**/
function replaceBBCodeParamsRaw(tag, emitter) {
  Discourse.Dialect.inlineBetween({
    start: "[" + tag + "=",
    stop: "[/" + tag + "]",
    rawContents: true,
    emitter: function(contents) {
      var regexp = /^([^\]]+)\](.*)$/,
          m = regexp.exec(contents);

      if (m) { return emitter.call(this, m[1], m[2]); }
    }
  });
}

/**
  Creates a BBCode handler that accepts parameters. Passes them to the emitter.
  Processes the inside recursively so it can be nested.

  @method replaceBBCodeParams
  @param {tag} tag the tag we want to match
  @param {function} emitter the function that creates JsonML for the tag
**/
function replaceBBCodeParams(tag, emitter) {
  replaceBBCodeParamsRaw(tag, function (param, contents) {
    return emitter(param, this.processInline(contents));
  });
}

replaceBBCode('b', function(contents) { return ['span', {'class': 'bbcode-b'}].concat(contents); });
replaceBBCode('i', function(contents) { return ['span', {'class': 'bbcode-i'}].concat(contents); });
replaceBBCode('u', function(contents) { return ['span', {'class': 'bbcode-u'}].concat(contents); });
replaceBBCode('s', function(contents) { return ['span', {'class': 'bbcode-s'}].concat(contents); });

replaceBBCode('ul', function(contents) { return ['ul'].concat(contents); });
replaceBBCode('ol', function(contents) { return ['ol'].concat(contents); });
replaceBBCode('li', function(contents) { return ['li'].concat(contents); });

rawBBCode('img', function(contents) { return ['img', {href: contents}]; });
rawBBCode('email', function(contents) { return ['a', {href: "mailto:" + contents, 'data-bbcode': true}, contents]; });
rawBBCode('url', function(contents) { return ['a', {href: contents, 'data-bbcode': true}, contents]; });
rawBBCode('spoiler', function(contents) {
  if (/<img/i.test(contents)) {
    return ['div', { 'class': 'spoiler' }, contents];
  } else {
    return ['span', { 'class': 'spoiler' }, contents];
  }
});

replaceBBCodeParamsRaw("url", function(param, contents) {
  return ['a', {href: param, 'data-bbcode': true}, contents];
});

replaceBBCodeParamsRaw("email", function(param, contents) {
  return ['a', {href: "mailto:" + param, 'data-bbcode': true}, contents];
});

replaceBBCodeParams("size", function(param, contents) {
  return ['span', {'class': "bbcode-size-" + (parseInt(param, 10) || 1)}].concat(contents);
});

// Handles `[code] ... [/code]` blocks
Discourse.Dialect.replaceBlock({
  start: /(\[code\])([\s\S]*)/igm,
  stop: '[/code]',
  rawContents: true,

  emitter: function(blockContents) {
    var inner = blockContents.join("\n").replace(/^\s+/,'');
    return ['p', ['pre', ['code', {'class': Discourse.SiteSettings.default_code_lang}, inner]]];
  }
});
