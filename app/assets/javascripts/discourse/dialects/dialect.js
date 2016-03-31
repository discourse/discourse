/*eslint no-bitwise:0 */

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
    hoisted,
    preProcessors = [],
    escape = Discourse.Utilities.escapeExpression;

/**
  Initialize our dialects for processing.

  @method initializeDialects
**/
function initializeDialects() {
  MD.buildBlockOrder(dialect.block);
  var index = dialect.block.__order__.indexOf("code");
  if (index > -1) {
    dialect.block.__order__.splice(index, 1);
    dialect.block.__order__.unshift("code");
  }
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
    var hash = Discourse.Dialect.guid();
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

  if (args.wordBoundary && (!last.match(/\W$/))) { return true; }
  if (args.spaceBoundary && (!last.match(/\s$/))) { return true; }
  if (args.spaceOrTagBoundary && (!last.match(/(\s|\>)$/))) { return true; }
}

/**
  Returns the number of (terminated) lines in a string.

  @method countLines
  @param {string} str the string.
  @returns {Integer} number of terminated lines in str
**/
function countLines(str) {
  var index = -1, count = 0;
  while ((index = str.indexOf("\n", index + 1)) !== -1) { count++; }
  return count;
}

function hoister(t, target, replacement) {
  var regexp = new RegExp(target.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&'), "g");
  if (t.match(regexp)) {
    var hash = Discourse.Dialect.guid();
    t = t.replace(regexp, hash);
    hoisted[hash] = replacement;
  }
  return t;
}

function outdent(t) {
  return t.replace(/^([ ]{4}|\t)/gm, "");
}

function removeEmptyLines(t) {
  return t.replace(/^\n+/, "")
          .replace(/\s+$/, "");
}

function hideBackslashEscapedCharacters(t) {
  return t.replace(/\\\\/g, "\u1E800")
          .replace(/\\`/g, "\u1E8001");
}

function showBackslashEscapedCharacters(t) {
  return t.replace(/\u1E8001/g, "\\`")
          .replace(/\u1E800/g, "\\\\");
}

function hoistCodeBlocksAndSpans(text) {
  // replace all "\`" with a single character
  text = hideBackslashEscapedCharacters(text);

  // /!\ the order is important /!\

  // fenced code blocks (AKA GitHub code blocks)
  text = text.replace(/(^\n*|\n)```([a-z0-9\-]*)\n([\s\S]*?)\n```/g, function(_, before, language, content) {
    var hash = Discourse.Dialect.guid();
    hoisted[hash] = escape(showBackslashEscapedCharacters(removeEmptyLines(content)));
    return before + "```" + language + "\n" + hash + "\n```";
  });

  // markdown code blocks
  text = text.replace(/(^\n*|\n\n)((?:(?:[ ]{4}|\t).*\n*)+)/g, function(match, before, content, index) {
    // make sure we aren't in a list
    var previousLine = text.slice(0, index).trim().match(/.*$/);
    if (previousLine && previousLine[0].length) {
      previousLine = previousLine[0].trim();
      if (/^(?:\*|\+|-|\d+\.)\s+/.test(previousLine)) {
        return match;
      }
    }
    // we can safely hoist the code block
    var hash = Discourse.Dialect.guid();
    hoisted[hash] = escape(outdent(showBackslashEscapedCharacters(removeEmptyLines(content))));
    return before + "    " + hash + "\n";
  });

  // <pre>...</pre> code blocks
  text = text.replace(/(\s|^)<pre>([\s\S]*?)<\/pre>/ig, function(_, before, content) {
    var hash = Discourse.Dialect.guid();
    hoisted[hash] = escape(showBackslashEscapedCharacters(removeEmptyLines(content)));
    return before + "<pre>" + hash + "</pre>";
  });

  // code spans (double & single `)
  ["``", "`"].forEach(function(delimiter) {
    var regexp = new RegExp("(^|[^`])" + delimiter + "([^`\\n]+?)" + delimiter + "([^`]|$)", "g");
    text = text.replace(regexp, function(_, before, content, after) {
      var hash = Discourse.Dialect.guid();
      hoisted[hash] = escape(showBackslashEscapedCharacters(content.trim()));
      return before + delimiter + hash + delimiter + after;
    });
  });

  // replace back all weird character with "\`"
  return showBackslashEscapedCharacters(text);
}

/**
  An object used for rendering our dialects.

  @class Dialect
  @namespace Discourse
  @module Discourse
**/
Discourse.Dialect = {

  // http://stackoverflow.com/a/8809472/17174
  guid: function(){
    var d = new Date().getTime();
    if(window.performance && typeof window.performance.now === "function"){
        d += performance.now(); //use high-precision timer if available
    }
    var uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = (d + Math.random() * 16) % 16 | 0;
        d = Math.floor(d/16);
        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
    });
    return uuid;
  },

  /**
    Cook text using the dialects.

    @method cook
    @param {String} text the raw text to cook
    @param {Object} opts hash of options
    @returns {String} the cooked text
  **/
  cook: function(text, opts) {
    if (!initialized) { initializeDialects(); }

    dialect.options = opts;

    // Helps us hoist out HTML
    hoisted = {};

    // pre-hoist all code-blocks/spans
    text = hoistCodeBlocksAndSpans(text);

    // pre-processors
    preProcessors.forEach(function(p) {
      text = p(text, hoister);
    });

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
      var found = true;

      var unhoist = function(key) {
        result = result.replace(new RegExp(key, "g"), function() {
          found = true;
          return hoisted[key];
        });
      };

      while(found) {
        found = false;
        keys.forEach(unhoist);
      }
    }

    return result.trim();
  },

  /**
    Adds a text pre-processor. Use only if necessary, as a dialect
    that emits JsonML is much better if possible.
  **/
  addPreProcessor: function(preProc) {
    preProcessors.push(preProc);
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

      var endPos = self.findEndPos(text, start, stop, args, startLength);
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

  findEndPos: function(text, start, stop, args, offset) {
    var endPos, nextStart;
    do {
      endPos = text.indexOf(stop, offset);
      if (endPos === -1) { return -1; }
      nextStart = text.indexOf(start, offset);
      offset = endPos + stop.length;
    } while (nextStart !== -1 && nextStart < endPos);
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
    var fn = function(block, next) {

      var linebreaks = dialect.options.traditional_markdown_linebreaks ||
          Discourse.SiteSettings.traditional_markdown_linebreaks;
      if (linebreaks && args.skipIfTradtionalLinebreaks) { return; }

      args.start.lastIndex = 0;
      var result = [], match = (args.start).exec(block);
      if (!match) { return; }

      var lastChance = function() {
        return !next.some(function(blk) { return blk.match(args.stop); });
      };

      // shave off start tag and leading text, if any.
      var pos = args.start.lastIndex - match[0].length,
          leading = block.slice(0, pos),
          trailing = match[2] ? match[2].replace(/^\n*/, "") : "";

      if(args.withoutLeading && args.withoutLeading.test(leading)) {
        //The other leading block should be processed first! eg a code block wrapped around a code block.
        return;
      }

      // just give up if there's no stop tag in this or any next block
      args.stop.lastIndex = block.length - trailing.length;
      if (!args.stop.exec(block) && lastChance()) { return; }
      if (leading.length > 0) {
        var parsedLeading = this.processBlock(MD.mk_block(leading), []);
        if (parsedLeading && parsedLeading[0]) {
          result.push(parsedLeading[0]);
        }
      }
      if (trailing.length > 0) {
        next.unshift(MD.mk_block(trailing, block.trailing,
          block.lineNumber + countLines(leading) + (match[2] ? match[2].length : 0) - trailing.length));
      }

      // go through the available blocks to find the matching stop tag.
      var contentBlocks = [], nesting = 0, actualEndPos = -1, currentBlock;
      blockloop:
      while (currentBlock = next.shift()) {
        // collect all the start and stop tags in the current block
        args.start.lastIndex = 0;
        var startPos = [], m;
        while (m = (args.start).exec(currentBlock)) {
          startPos.push(args.start.lastIndex - m[0].length);
          args.start.lastIndex = args.start.lastIndex - (m[2] ? m[2].length : 0);
        }
        args.stop.lastIndex = 0;
        var endPos = [];
        while (m = (args.stop).exec(currentBlock)) {
          endPos.push(args.stop.lastIndex - m[0].length);
        }

        // go through the available end tags:
        var ep = 0, sp = 0; // array indices
        while (ep < endPos.length) {
          if (sp < startPos.length && startPos[sp] < endPos[ep]) {
            // there's an end tag, but there's also another start tag first. we need to go deeper.
            sp++; nesting++;
          } else if (nesting > 0) {
            // found an end tag, but we must go up a level first.
            ep++; nesting--;
          } else {
            // found an end tag and we're at the top: done! -- or: start tag and end tag are
            // identical, (i.e. startPos[sp] == endPos[ep]), so we don't do nesting at all.
            actualEndPos = endPos[ep];
            break blockloop;
          }
        }

        if (lastChance()) {
          // when lastChance() becomes true the first time, currentBlock contains the last
          // end tag available in the input blocks but it's not on the right nesting level
          // or we would have terminated the loop already. the only thing we can do is to
          // treat the last available end tag as tho it were matched with our start tag
          // and let the emitter figure out how to render the garbage inside.
          actualEndPos = endPos[endPos.length - 1];
          break;
        }

        // any left-over start tags still increase the nesting level
        nesting += startPos.length - sp;
        contentBlocks.push(currentBlock);
      }

      var stopLen = currentBlock.match(args.stop)[0].length,
          before = currentBlock.slice(0, actualEndPos).replace(/\n*$/, ""),
          after = currentBlock.slice(actualEndPos + stopLen).replace(/^\n*/, "");
      if (before.length > 0) contentBlocks.push(MD.mk_block(before, "", currentBlock.lineNumber));
      if (after.length > 0) next.unshift(MD.mk_block(after, currentBlock.trailing, currentBlock.lineNumber + countLines(before)));

      var emitterResult = args.emitter.call(this, contentBlocks, match, dialect.options);
      if (emitterResult) { result.push(emitterResult); }
      return result;
    };

    if (args.priority) {
      fn.priority = args.priority;
    }

    this.registerBlock(args.start.toString(), fn);
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


