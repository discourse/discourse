/**

  Discourse uses the Markdown.js as its main parser. `Discourse.Dialect` is the framework
  for extending it with additional formatting.

  To extend the dialect, you can register a handler, and you will receive an `event` object
  with a handle to the markdown `Dialect` from Markdown.js that we are defining. Here's
  a sample dialect that replaces all occurrences of "evil trout" with a link that says
  "EVIL TROUT IS AWESOME":

  ```javascript

    Discourse.Dialect.on("register", function(event) {
      var dialect = event.dialect;

      // To see how this works, review one of our samples or the Markdown.js code:
      dialect.inline["evil trout"] = function(text) {
        return ["evil trout".length, ['a', {href: "http://eviltrout.com"}, "EVIL TROUT IS AWESOME"] ];
      };

    });
  ```

  You can also manipulate the JsonML tree that is produced by the parser before it converted to HTML.
  This is useful if the markup you want needs a certain structure of HTML elements. Rather than
  writing regular expressions to match HTML, consider parsing the tree instead! We use this for
  making sure a onebox is on one line, as an example.

  This example changes the content of any `<code>` tags.

  The `event.path` attribute contains the current path to the node.

  ```javascript
    Discourse.Dialect.on("parseNode", function(event) {
      var node = event.node;

      if (node[0] === 'code') {
        node[node.length-1] = "EVIL TROUT HACKED YOUR CODE";
      }
    });
  ```

**/
var parser = window.BetterMarkdown,
    MD = parser.Markdown,
    dialect = MD.dialects.Discourse = MD.subclassDialect( MD.dialects.Gruber ),
    initialized = false;

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
  Parse a JSON ML tree, using registered handlers to adjust it if necessary.

  @method parseTree
  @param {Array} tree the JsonML tree to parse
  @param {Array} path the path of ancestors to the current node in the tree. Can be used for matching.
  @param {Object} insideCounts counts what tags we're inside
  @returns {Array} the parsed tree
**/
function parseTree(tree, path, insideCounts) {
  if (tree instanceof Array) {
    Discourse.Dialect.trigger('parseNode', {node: tree, path: path, dialect: dialect, insideCounts: insideCounts || {}});

    path = path || [];
    insideCounts = insideCounts || {};

    path.push(tree);
    tree.slice(1).forEach(function (n) {
      var tagName = n[0];
      insideCounts[tagName] = (insideCounts[tagName] || 0) + 1;
      parseTree(n, path, insideCounts);
      insideCounts[tagName] = insideCounts[tagName] - 1;
    });
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

  if (args.wordBoundary && (!last.match(/\W$/))) { return true; }
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
    var tree = parser.toHTMLTree(text, 'Discourse');
    return parser.renderJsonML(parseTree(tree));
  },

  /**
    The simplest kind of replacement possible. Replace a stirng token with JsonML.

    For example to replace all occurrances of :) with a smile image:

     ```javascript
      Discourse.Dialect.inlineReplace(':)', ['img', {src: '/images/smile.gif'}])
    ```

    @method inlineReplace
    @param {String} token The token we want to replace
    @param {Array} jsonml The JsonML to replace it with.
  **/
  inlineReplace: function(token, jsonml) {
    dialect.inline[token] = function(text, match, prev) {
      return [token.length, jsonml];
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

  }

};

RSVP.EventTarget.mixin(Discourse.Dialect);


