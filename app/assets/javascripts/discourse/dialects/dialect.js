/*global md5:true */
/**

  Discourse uses the Markdown.js as its main parser. `Discourse.Dialect` is the framework
  for extending it with additional formatting.

**/
var parser = window.BetterMarkdown,
    MD = parser.Markdown,
    DialectHelpers = parser.DialectHelpers,
    dialect = MD.dialects.Discourse = DialectHelpers.subclassDialect( MD.dialects.Gruber ),
    initialized = false,
    emitters = [],
    hoisted;

/**
  Initialize our dialects for processing.

  @method initializeDialects
**/
function initializeDialects() {
  MD.buildBlockOrder(dialect.block);
  MD.buildInlinePatterns(dialect.inline);
  initialized = true;
}

/**
  Process the text nodes in the JsonML tree, calling any emitters that have
  been added.

  @method processTextNodes
  @param {Array} node the JsonML tree
  @param {Object} event the parse node event data
  @param {Function} emitter the function to call on the text node
**/
function processTextNodes(node, event, emitter) {
  if (node.length < 2) { return; }

  if (node[0] === '__RAW') {
    var hash = md5(node[1]);
    hoisted[hash] = node[1];
    node[1] = hash;
    return;
  }

  for (var j=1; j<node.length; j++) {
    var textContent = node[j];
    if (typeof textContent === "string") {
      var result = emitter(textContent, event);
      if (result) {
        if (result instanceof Array) {
          node.splice.apply(node, [j, 1].concat(result));
        } else {
          node[j] = result;
        }
      } else {
        node[j] = textContent;
      }

    }
  }
}


/**
  Parse a JSON ML tree, using registered handlers to adjust it if necessary.

  @method parseTree
  @param {Array} tree the JsonML tree to parse
  @param {Array} path the path of ancestors to the current node in the tree. Can be used for matching.
  @param {Object} insideCounts counts what tags we're inside
  @returns {Array} the parsed tree
**/
function parseTree(tree, path, insideCounts) {

  if (tree instanceof Array) {
    var event = {node: tree, path: path, dialect: dialect, insideCounts: insideCounts || {}};
    Discourse.Dialect.trigger('parseNode', event);

    for (var j=0; j<emitters.length; j++) {
      processTextNodes(tree, event, emitters[j]);
    }

    path = path || [];
    insideCounts = insideCounts || {};

    path.push(tree);

    for (var i=1; i<tree.length; i++) {
      var n = tree[i],
          tagName = n[0];

      insideCounts[tagName] = (insideCounts[tagName] || 0) + 1;

      if (n && n.length === 2 && n[0] === "p" && /^<!--([\s\S]*)-->$/.exec(n[1])) {
        // Remove paragraphs around comment-only nodes.
        tree[i] = n[1];
      } else {
        parseTree(n, path, insideCounts);
      }

      insideCounts[tagName] = insideCounts[tagName] - 1;
    }

    // If raw nodes are in paragraphs, pull them up
    if (tree.length === 2 && tree[0] === 'p' && tree[1] instanceof Array && tree[1][0] === "__RAW") {
      var text = tree[1][1];
      tree[0] = "__RAW";
      tree[1] = text;
    }

    path.pop();
  }
  return tree;
}

/**
  Returns true if there's an invalid word boundary for a match.

  @method invalidBoundary
  @param {Object} args our arguments, including whether we care about boundaries
  @param {Array} prev the previous content, if exists
  @returns {Boolean} whether there is an invalid word boundary
**/
function invalidBoundary(args, prev) {
  if (!(args.wordBoundary || args.spaceBoundary || args.spaceOrTagBoundary)) { return false; }

  var last = prev[prev.length - 1];
  if (typeof last !== "string") { return false; }

  if (args.wordBoundary && (last.match(/(\w|\/)$/))) { return true; }
  if (args.spaceBoundary && (!last.match(/\s$/))) { return true; }
  if (args.spaceOrTagBoundary && (!last.match(/(\s|\>)$/))) { return true; }
}

/**
  An object used for rendering our dialects.

  @class Dialect
  @namespace Discourse
  @module Discourse
**/
Discourse.Dialect = {

  /**
    Cook text using the dialects.

    @method cook
    @param {String} text the raw text to cook
    @param {Object} opts hash of options
    @returns {String} the cooked text
  **/
  cook: function(text, opts) {
    if (!initialized) { initializeDialects(); }
    hoisted = {};
    dialect.options = opts;
    var tree = parser.toHTMLTree(text, 'Discourse'),
        result = parser.renderJsonML(parseTree(tree));

    if (opts.sanitize) {
      result = Discourse.Markdown.sanitize(result);
    } else if (opts.sanitizerFunction) {
      result = opts.sanitizerFunction(result);
    }

    // If we hoisted out anything, put it back
    var keys = Object.keys(hoisted);
    if (keys.length) {
      keys.forEach(function(k) {
        result = result.replace(new RegExp(k,"g"), hoisted[k]);
      });
    }

    hoisted = {};
    return result.trim();
  },

  /**
    Registers an inline replacer function

    @method registerInline
    @param {String} start The token the replacement begins with
    @param {Function} fn The replacing function
  **/
  registerInline: function(start, fn) {
    dialect.inline[start] = fn;
  },


  /**
    The simplest kind of replacement possible. Replace a stirng token with JsonML.

    For example to replace all occurrances of :) with a smile image:

    ```javascript
      Discourse.Dialect.inlineReplace(':)', function (text) {
        return ['img', {src: '/images/smile.png'}];
      });

    ```

    @method inlineReplace
    @param {String} token The token we want to replace
    @param {Function} emitter A function that emits the JsonML for the replacement.
  **/
  inlineReplace: function(token, emitter) {
    this.registerInline(token, function(text, match, prev) {
      return [token.length, emitter.call(this, token, match, prev)];
    });
  },

  /**
    Matches inline using a regular expression. The emitter function is passed
    the matches from the regular expression.

    For example, this auto links URLs:

    ```javascript
      Discourse.Dialect.inlineRegexp({
        matcher: /((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/gm,
        spaceBoundary: true,
        start: 'http',

        emitter: function(matches) {
          var url = matches[1];
          return ['a', {href: url}, url];
        }
      });
    ```

    @method inlineRegexp
    @param {Object} args Our replacement options
      @param {Function} [opts.emitter] The function that will be called with the contents and regular expresison match and returns JsonML.
      @param {String} [opts.start] The starting token we want to find
      @param {String} [opts.matcher] The regular expression to match
      @param {Boolean} [opts.wordBoundary] If true, the match must be on a word boundary
      @param {Boolean} [opts.spaceBoundary] If true, the match must be on a space boundary
  **/
  inlineRegexp: function(args) {
    this.registerInline(args.start, function(text, match, prev) {
      if (invalidBoundary(args, prev)) { return; }

      args.matcher.lastIndex = 0;
      var m = args.matcher.exec(text);
      if (m) {
        var result = args.emitter.call(this, m);
        if (result) {
          return [m[0].length, result];
        }
      }
    });
  },

  /**
    Handles inline replacements surrounded by tokens.

    For example, to handle markdown style bold. Note we use `concat` on the array because
    the contents are JsonML too since we didn't pass `rawContents` as true. This supports
    recursive markup.

    ```javascript

      Discourse.Dialect.inlineBetween({
        between: '**',
        wordBoundary: true.
        emitter: function(contents) {
          return ['strong'].concat(contents);
        }
      });
    ```

    @method inlineBetween
    @param {Object} args Our replacement options
      @param {Function} [opts.emitter] The function that will be called with the contents and returns JsonML.
      @param {String} [opts.start] The starting token we want to find
      @param {String} [opts.stop] The ending token we want to find
      @param {String} [opts.between] A shortcut for when the `start` and `stop` are the same.
      @param {Boolean} [opts.rawContents] If true, the contents between the tokens will not be parsed.
      @param {Boolean} [opts.wordBoundary] If true, the match must be on a word boundary
      @param {Boolean} [opts.spaceBoundary] If true, the match must be on a space boundary
  **/
  inlineBetween: function(args) {
    var start = args.start || args.between,
        stop = args.stop || args.between,
        startLength = start.length,
        self = this;

    this.registerInline(start, function(text, match, prev) {
      if (invalidBoundary(args, prev)) { return; }

      var endPos = self.findEndPos(text, stop, args, startLength);
      if (endPos === -1) { return; }
      var between = text.slice(startLength, endPos);

      // If rawcontents is set, don't process inline
      if (!args.rawContents) {
        between = this.processInline(between);
      }

      var contents = args.emitter.call(this, between);
      if (contents) {
        return [endPos+stop.length, contents];
      }
    });
  },

  findEndPos: function(text, stop, args, start) {
    var endPos = text.indexOf(stop, start);
    if (endPos === -1) { return -1; }
    var after = text.charAt(endPos + stop.length);
    if (after && after.indexOf(stop) === 0) {
      return this.findEndPos(text, stop, args, endPos + stop.length + 1);
    }
    return endPos;
  },

  /**
    Registers a block for processing. This is more complicated than using one of
    the other helpers such as `replaceBlock` so consider using them first!

    @method registerBlock
    @param {String} name the name of the block handler
    @param {Function} handler the handler
  **/
  registerBlock: function(name, handler) {
    dialect.block[name] = handler;
  },

  /**
    Replaces a block of text between a start and stop. As opposed to inline, these
    might span multiple lines.

    Here's an example that takes the content between `[code]` ... `[/code]` and
    puts them inside a `pre` tag:

    ```javascript
      Discourse.Dialect.replaceBlock({
        start: /(\[code\])([\s\S]*)/igm,
        stop: '[/code]',
        rawContents: true,

        emitter: function(blockContents) {
          return ['p', ['pre'].concat(blockContents)];
        }
      });
    ```

    @method replaceBlock
    @param {Object} args Our replacement options
      @param {RegExp} [args.start] The starting regexp we want to find
      @param {String} [args.stop] The ending token we want to find
      @param {Boolean} [args.rawContents] True to skip recursive processing
      @param {Function} [args.emitter] The emitting function to transform the contents of the block into jsonML

  **/
  replaceBlock: function(args) {
    this.registerBlock(args.start.toString(), function(block, next) {

      var linebreaks = dialect.options.traditional_markdown_linebreaks ||
          Discourse.SiteSettings.traditional_markdown_linebreaks;

      // Some replacers should not be run with traditional linebreaks
      if (linebreaks && args.skipIfTradtionalLinebreaks) { return; }

      args.start.lastIndex = 0;
      var m = (args.start).exec(block);

      if (!m) { return; }

      var startPos = args.start.lastIndex - m[0].length,
          leading,
          blockContents = [],
          result = [],
          lineNumber = block.lineNumber;

      if (startPos > 0) {
        leading = block.slice(0, startPos);
        lineNumber += (leading.split("\n").length - 1);

        var para = ['p'];
        this.processInline(leading).forEach(function (l) {
          para.push(l);
        });

        result.push(para);
      }

      if (m[2]) {
        next.unshift(MD.mk_block(m[2], null, lineNumber + 1));
      }

      lineNumber++;

      var blockClosed = false;
      for (var i=0; i<next.length; i++) {
        if (next[i].indexOf(args.stop) >= 0) {
          blockClosed = true;
          break;
        }
      }

      if (!blockClosed) {
        if (m[2]) { next.shift(); }
        return;
      }

      var numOpen = 1;
      while (next.length > 0) {
        var b = next.shift(),
            blockLine = b.lineNumber,
            diff = ((typeof blockLine === "undefined") ? lineNumber : blockLine) - lineNumber,
            endFound = b.indexOf(args.stop),
            leadingContents = b.slice(0, endFound),
            trailingContents = b.slice(endFound+args.stop.length),
            m2;

        if (endFound === -1) {
          leadingContents = b;
        }

        args.start.lastIndex = 0;
        if (m2 = (args.start).exec(leadingContents)) {
          numOpen++;
          args.start.lastIndex -= m2[0].length - 1;
          while (m2 = (args.start).exec(leadingContents)) {
            numOpen++;
            args.start.lastIndex -= m2[0].length - 1;
          }
        }

        if (endFound >= 0) { numOpen--; }
        for (var j=1; j<diff; j++) {
          blockContents.push("");
        }
        lineNumber = blockLine + b.split("\n").length - 1;

        if (endFound >= 0) {
          if (trailingContents) {
            next.unshift(MD.mk_block(trailingContents.replace(/^\s+/, "")));
          }

          blockContents.push(leadingContents.replace(/\s+$/, ""));

          if (numOpen === 0) {
            break;
          }
          blockContents.push(args.stop);
        } else {
          blockContents.push(b);
        }
      }

      var emitterResult = args.emitter.call(this, blockContents, m, dialect.options);
      if (emitterResult) {
        result.push(emitterResult);
      }
      return result;
    });
  },

  /**
    After the parser has been executed, post process any text nodes in the HTML document.
    This is useful if you want to apply a transformation to the text.

    If you are generating HTML from the text, it is preferable to use the replacer
    functions and do it in the parsing part of the pipeline. This function is best for
    simple transformations or transformations that have to happen after all earlier
    processing is done.

    For example, to convert all text to upper case:

    ```javascript

      Discourse.Dialect.postProcessText(function (text) {
        return text.toUpperCase();
      });

    ```

    @method postProcessText
    @param {Function} emitter The function to call with the text. It returns JsonML to modify the tree.
  **/
  postProcessText: function(emitter) {
    emitters.push(emitter);
  },

  /**
    After the parser has been executed, change the contents of a HTML tag.

    Let's say you want to replace the contents of all code tags to prepend
    "EVIL TROUT HACKED YOUR CODE!":

    ```javascript
      Discourse.Dialect.postProcessTag('code', function (contents) {
        return "EVIL TROUT HACKED YOUR CODE!\n\n" + contents;
      });
    ```

    @method postProcessTag
    @param {String} tag The HTML tag you want to match on
    @param {Function} emitter The function to call with the text. It returns JsonML to modify the tree.
  **/
  postProcessTag: function(tag, emitter) {
    Discourse.Dialect.on('parseNode', function (event) {
      var node = event.node;
      if (node[0] === tag) {
        node[node.length-1] = emitter(node[node.length-1]);
      }
    });
  }

};

RSVP.EventTarget.mixin(Discourse.Dialect);


