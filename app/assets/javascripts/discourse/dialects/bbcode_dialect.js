/**
  Regsiter all functionality for supporting BBCode in Discourse.

  @event register
  @namespace Discourse.Dialect
**/
Discourse.Dialect.on("register", function(event) {

  var dialect = event.dialect,
      MD = event.MD;

  var createBBCode = function(tag, builder, hasArgs) {
    return function(text, orig_match) {
      var bbcodePattern = new RegExp("\\[" + tag + "=?([^\\[\\]]+)?\\]([\\s\\S]*?)\\[\\/" + tag + "\\]", "igm");
      var m = bbcodePattern.exec(text);
      if (m && m[0]) {
        return [m[0].length, builder(m, this)];
      }
    };
  };

  var bbcodes = {'b': ['span', {'class': 'bbcode-b'}],
                  'i': ['span', {'class': 'bbcode-i'}],
                  'u': ['span', {'class': 'bbcode-u'}],
                  's': ['span', {'class': 'bbcode-s'}],
                  'spoiler': ['span', {'class': 'spoiler'}],
                  'li': ['li'],
                  'ul': ['ul'],
                  'ol': ['ol']};

  Object.keys(bbcodes).forEach(function(tag) {
    var element = bbcodes[tag];
    dialect.inline["[" + tag + "]"] = createBBCode(tag, function(m, self) {
      return element.concat(self.processInline(m[2]));
    });
  });

  dialect.inline["[img]"] = createBBCode('img', function(m) {
    return ['img', {href: m[2]}];
  });

  dialect.inline["[email]"] = createBBCode('email', function(m) {
    return ['a', {href: "mailto:" + m[2], 'data-bbcode': true}, m[2]];
  });

  dialect.inline["[url]"] = createBBCode('url', function(m) {
    return ['a', {href: m[2], 'data-bbcode': true}, m[2]];
  });

  dialect.inline["[url="] = createBBCode('url', function(m, self) {
    return ['a', {href: m[1], 'data-bbcode': true}].concat(self.processInline(m[2]));
  });

  dialect.inline["[email="] = createBBCode('email', function(m, self) {
    return ['a', {href: "mailto:" + m[1], 'data-bbcode': true}].concat(self.processInline(m[2]));
  });

  dialect.inline["[size="] = createBBCode('size', function(m, self) {
    return ['span', {'class': "bbcode-size-" + m[1]}].concat(self.processInline(m[2]));
  });

  dialect.inline["[color="] = function(text, orig_match) {
    var bbcodePattern = new RegExp("\\[color=?([^\\[\\]]+)?\\]([\\s\\S]*?)\\[\\/color\\]", "igm"),
        m = bbcodePattern.exec(text);

    if (m && m[0]) {
      if (!/^(\#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?)|(aqua|black|blue|fuchsia|gray|green|lime|maroon|navy|olive|purple|red|silver|teal|white|yellow)$/.test(m[1])) {
        return [m[0].length].concat(this.processInline(m[2]));
      }
      return [m[0].length, ['span', {style: "color: " + m[1]}].concat(this.processInline(m[2]))];
    }
  };

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
  dialect.inline["[quote="] = function bbcodeQuote(text, orig_match) {
    var bbcodePattern = new RegExp("\\[quote=?([^\\[\\]]+)?\\]([\\s\\S]*?)\\[\\/quote\\]", "igm"),
        m = bbcodePattern.exec(text);

    if (!m) { return; }
    var paramsString = m[1].replace(/\"/g, ''),
        params = {'class': 'quote'},
        paramsSplit = paramsString.split(/\, */),
        username = paramsSplit[0],
        opts = dialect.options;

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

    var quote = ['aside', params,
                    ['div', {'class': 'title'},
                      ['div', {'class': 'quote-controls'}],
                      avatarImg ? avatarImg + "\n" : "",
                      I18n.t('user.said',{username: username})
                    ],
                    ['blockquote'].concat(this.processInline(m[2]))
                 ];

    return [m[0].length, quote];
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
