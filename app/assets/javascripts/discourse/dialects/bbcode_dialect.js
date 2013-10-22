/**
  Create a simple BBCode tag handler

  @method replaceBBCode
  @param {tag} tag the tag we want to match
  @param {function} emitter the function that creates JsonML for the tag
**/
function replaceBBCode(tag, emitter) {
  Discourse.Dialect.inlineBetween({
    start: "[" + tag + "]",
    stop: "[/" + tag + "]",
    emitter: emitter
  });
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

replaceBBCode('spoiler', function(contents) { return ['span', {'class': 'spoiler'}].concat(contents); });

Discourse.Dialect.inlineBetween({
  start: '[img]',
  stop: '[/img]',
  rawContents: true,
  emitter: function(contents) { return ['img', {href: contents}]; }
});

Discourse.Dialect.inlineBetween({
  start: '[email]',
  stop: '[/email]',
  rawContents: true,
  emitter: function(contents) { return ['a', {href: "mailto:" + contents, 'data-bbcode': true}, contents]; }
});

Discourse.Dialect.inlineBetween({
  start: '[url]',
  stop: '[/url]',
  rawContents: true,
  emitter: function(contents) { return ['a', {href: contents, 'data-bbcode': true}, contents]; }
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

  emitter: function(blockContents) {
    return ['p', ['pre'].concat(blockContents.join("\n"))];
  }
});

