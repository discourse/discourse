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
  return ['span', {'class': "bbcode-size-" + param}].concat(contents);
});

replaceBBCodeParams("color", function(param, contents) {
  // Only allow valid HTML colors.
  if (/^(\#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?)|(aqua|black|blue|fuchsia|gray|green|lime|maroon|navy|olive|purple|red|silver|teal|white|yellow)$/.test(param)) {
    return ['span', {style: "color: " + param}].concat(contents);
  } else {
    return ['span'].concat(contents);
  }
});

Discourse.Dialect.on("register", function(event) {

  var dialect = event.dialect,
      MD = event.MD;

  /**
    Support BBCode [code] blocks

    @method bbcodeCode
    @param {Markdown.Block} block the block to examine
    @param {Array} next the next blocks in the sequence
    @return {Array} the JsonML containing the markup or undefined if nothing changed.
    @namespace Discourse.Dialect
  **/
  dialect.inline["[code]"] = function bbcodeCode(text, orig_match) {
    var bbcodePattern = new RegExp("\\[code\\]([\\s\\S]*?)\\[\\/code\\]", "igm"),
        m = bbcodePattern.exec(text);

    if (m) {
      var contents = m[1].trim().split("\n");

      var html = ['pre', "\n"];
      contents.forEach(function (n) {
        html.push(n.trim());
        html.push(["br"]);
        html.push("\n");
      });

      return [m[0].length, html];
    }
  };

  /**
    Support BBCode [quote] blocks

    @method bbcodeQuote
    @param {Markdown.Block} block the block to examine
    @param {Array} next the next blocks in the sequence
    @return {Array} the JsonML containing the markup or undefined if nothing changed.
    @namespace Discourse.Dialect
  **/
  dialect.block['quote'] = function bbcodeQuote(block, next) {
    var m = new RegExp("\\[quote=?([^\\[\\]]+)?\\]([\\s\\S]*)", "igm").exec(block);
    if (m) {
      var paramsString = m[1].replace(/\"/g, ''),
          params = {'class': 'quote'},
          paramsSplit = paramsString.split(/\, */),
          username = paramsSplit[0],
          opts = dialect.options,
          startPos = block.indexOf(m[0]),
          leading,
          quoteContents = [],
          result = [];

      if (startPos > 0) {
        leading = block.slice(0, startPos);

        var para = ['p'];
        this.processInline(leading).forEach(function (l) {
          para.push(l);
        });

        result.push(para);
      }

      paramsSplit.forEach(function(p,i) {
        if (i > 0) {
          var assignment = p.split(':');
          if (assignment[0] && assignment[1]) {
            params['data-' + assignment[0]] = assignment[1].trim();
          }
        }
      });

      var avatarImg;
      if (opts.lookupAvatarByPostNumber) {
        // client-side, we can retrieve the avatar from the post
        var postNumber = parseInt(params['data-post'], 10);
        avatarImg = opts.lookupAvatarByPostNumber(postNumber);
      } else if (opts.lookupAvatar) {
        // server-side, we need to lookup the avatar from the username
        avatarImg = opts.lookupAvatar(username);
      }

      if (m[2]) { next.unshift(MD.mk_block(m[2])); }

      while (next.length > 0) {
        var b = next.shift(),
            n = b.match(/([\s\S]*)\[\/quote\]([\s\S]*)/m);

        if (n) {
          if (n[2]) {
            next.unshift(MD.mk_block(n[2]));
          }
          quoteContents.push(n[1]);
          break;
        } else {
          quoteContents.push(b);
        }
      }

      var contents = this.processInline(quoteContents.join("  \n  \n"));
      contents.unshift('blockquote');


      result.push(['p', ['aside', params,
                   ['div', {'class': 'title'},
                     ['div', {'class': 'quote-controls'}],
                     avatarImg ? avatarImg : "",
                     I18n.t('user.said',{username: username})
                   ],
                   contents
                ]]);
      return result;
    }
  };

});


Discourse.Dialect.on("parseNode", function(event) {

  var node = event.node,
      path = event.path;

  // Make sure any quotes are followed by a <br>. The formatting looks weird otherwise.
  if (node[0] === 'aside' && node[1] && node[1]['class'] === 'quote') {
    var parent = path[path.length - 1],
        location = parent.indexOf(node)+1,
        trailing = parent.slice(location);

    if (trailing.length) {
      parent.splice(location, 0, ['br']);
    }
  }

});
