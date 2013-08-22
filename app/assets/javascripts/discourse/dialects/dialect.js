/**

  Discourse uses the Markdown.js as its main parser. `Discourse.Dialect` is the framework
  for extending it with additional formatting.

  To extend the dialect, you can register a handler, and you will receive an `event` object
  with a handle to the markdown `Dialect` from Markdown.js that we are defining. Here's
  a sample dialect that replaces all occurances of "evil trout" with a link that says
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
      var node = event.node,
          path = event.path;

      if (node[0] === 'code') {
        node[node.length-1] = "EVIL TROUT HACKED YOUR CODE";
      }
    });
  ```

**/
var parser = window.BetterMarkdown,
    MD = parser.Markdown,

    // Our dialect
    dialect = MD.dialects.Discourse = MD.subclassDialect( MD.dialects.Gruber ),

    initialized = false,

    /**
      Initialize our dialects for processing.

      @method initializeDialects
    **/
    initializeDialects = function() {
      Discourse.Dialect.trigger('register', {dialect: dialect, MD: MD});
      MD.buildBlockOrder(dialect.block);
      MD.buildInlinePatterns(dialect.inline);
      initialized = true;
    },

    /**
      Parse a JSON ML tree, using registered handlers to adjust it if necessary.

      @method parseTree
      @param {Array} tree the JsonML tree to parse
      @param {Array} path the path of ancestors to the current node in the tree. Can be used for matching.
      @returns {Array} the parsed tree
    **/
    parseTree = function parseTree(tree, path) {
      if (tree instanceof Array) {
        Discourse.Dialect.trigger('parseNode', {node: tree, path: path});

        path = path || [];
        path.push(tree);
        tree.slice(1).forEach(function (n) {
          parseTree(n, path);
        });
        path.pop();
      }
      return tree;
    };

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
    return parser.renderJsonML(parseTree(parser.toHTMLTree(text, 'Discourse')));
  }
};

RSVP.EventTarget.mixin(Discourse.Dialect);
