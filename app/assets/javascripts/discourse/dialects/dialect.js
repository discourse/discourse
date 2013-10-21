/**

  Discourse uses the Markdown.js as its main parser. `Discourse.Dialect` is the framework
  for extending it with additional formatting.

**/
var parser = window.BetterMarkdown,
    MD = parser.Markdown,
    DialectHelpers = parser.DialectHelpers,
    dialect = MD.dialects.Discourse = DialectHelpers.subclassDialect( MD.dialects.Gruber ),
    initialized = false,
    emitters = [];

/**
  Initialize our dialects for processing.

  @method initializeDialects
**/
function initializeDialects() {
  Discourse.Dialect.trigger('register', {dialect: dialect, MD: MD});
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
**/
function processTextNodes(node, event) {
  if (node.length < 2) { return; }

  if (node[0] === '__RAW') {
    return;
  }

  var skipSanitize = [];
  for (var j=1; j<node.length; j++) {
    var textContent = node[j];
    if (typeof textContent === "string") {

      if (dialect.options.sanitize && !skipSanitize[textContent]) {
        textContent = Discourse.Markdown.sanitize(textContent);
      }

      var result = textContent;

      for (var k=0; k<emitters.length; k++) {
        result = emitters[k](result, event);
      }

      if (result) {
        if (result instanceof Array) {
          for (var i=0; i<result.length; i++) {
            skipSanitize[result[i]] = true;
          }
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
    processTextNodes(tree, event);

    path = path || [];
    insideCounts = insideCounts || {};

    path.push(tree);

    for (var i=1; i<tree.length; i++) {
      var n = tree[i],
          tagName = n[0];

      insideCounts[tagName] = (insideCounts[tagName] || 0) + 1;

      if (n && n.length === 2 && n[0] === "p" && /^<!--([\s\S]*)-->$/m.exec(n[1])) {
        // Remove paragraphs around comment-only nodes.
        tree[i] = n[1];
      } else {
        parseTree(n, path, insideCounts);
      }

      insideCounts[tagName] = insideCounts[tagName] - 1;
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

  if (!args.wordBoundary && !args.spaceBoundary) { return; }

  var last = prev[prev.length - 1];
  if (typeof last !== "string") { return; }

  if (args.wordBoundary && (last.match(/(\w|\/)$/))) { return true; }
  if (args.spaceBoundary && (!last.match(/\s$/))) { return true; }
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
    @returns {String} the cooked text
  **/
  cook: function(text, opts) {
    if (!initialized) { initializeDialects(); }
    dialect.options = opts;
    var tree = parser.toHTMLTree(text, 'Discourse'),
        html = parser.renderJsonML(parseTree(tree));

    return html;
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
    dialect.inline[token] = function(text, match, prev) {
      return [token.length, emitter.call(this, token)];
    };
  },

  /**
    Matches inline using a regular expression. The emitter function is passed
    the matches from the regular expression.

    For example, this auto links URLs:

    ```javascript
      Discourse.Dialect.inlineRegexp({
        matcher: /((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/gm,
        spaceBoundary: true,

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
      @param {Boolean} [opts.spaceBoundary] If true, the match must be on a sppace boundary
  **/
  inlineRegexp: function(args) {
    dialect.inline[args.start] = function(text, match, prev) {
      if (invalidBoundary(args, prev)) { return; }

      args.matcher.lastIndex = 0;
      var m = args.matcher.exec(text);
      if (m) {
        var result = args.emitter.call(this, m);
        if (result) {
          return [m[0].length, result];
        }
      }
    };
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
      @param {Boolean} [opts.spaceBoundary] If true, the match must be on a sppace boundary
  **/
  inlineBetween: function(args) {
    var start = args.start || args.between,
        stop = args.stop || args.between,
        startLength = start.length;

    dialect.inline[start] = function(text, match, prev) {
      if (invalidBoundary(args, prev)) { return; }

      var endPos = text.indexOf(stop, startLength);
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
    };
  },

  /**
    Registers a block for processing. This is more complicated than using one of
    the other helpers such as `replaceBlock` so consider using them first!

    @method registerBlock
    @param {String} the name of the block handler
    @param {Function} the handler

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

        emitter: function(blockContents) {
          return ['p', ['pre'].concat(blockContents)];
        }
      });
    ```

    @method replaceBlock
    @param {Object} args Our replacement options
      @param {String} [opts.start] The starting regexp we want to find
      @param {String} [opts.stop] The ending token we want to find
      @param {Function} [opts.emitter] The emitting function to transform the contents of the block into jsonML

  **/
  replaceBlock: function(args) {
    this.registerBlock(args.start.toString(), function(block, next) {

      args.start.lastIndex = 0;
      var m = (args.start).exec(block);

      if (!m) { return; }

      var startPos = block.indexOf(m[0]),
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
      if (next.length > 0) {
        for (var i=0; i<next.length; i++) {
          if (next[i].indexOf(args.stop) >= 0) {
            blockClosed = true;
            break;
          }
        }
      }

      if (!blockClosed) {
        if (m[2]) { next.shift(); }
        return;
      }

      while (next.length > 0) {
        var b = next.shift(),
            blockLine = b.lineNumber,
            diff = ((typeof blockLine === "undefined") ? lineNumber : blockLine) - lineNumber,
            endFound = b.indexOf(args.stop),
            leadingContents = b.slice(0, endFound),
            trailingContents = b.slice(endFound+args.stop.length);

        if (endFound >= 0) { blockClosed = true; }
        for (var j=1; j<diff; j++) {
          blockContents.push("");
        }
        lineNumber = blockLine + b.split("\n").length - 1;

        if (endFound !== -1) {
          if (trailingContents) {
            next.unshift(MD.mk_block(trailingContents.replace(/^\s+/, "")));
          }

          blockContents.push(leadingContents.replace(/\s+$/, ""));
          break;
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


